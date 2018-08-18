require 'fileutils'
require 'thread'
require 'job'
require 'wrong_slice'
require 'compilation_slice'
require 'activerecord-import'

module Fdse
  class FailReason
    def self.maven_slice(file_array)
      wrong_mark = []
      wrong_lines = []
      wrong_section_started = false

      file_array.each do |line|
        if ! line.valid_encoding?
          line = line.encode("UTF-16be", :invalid=>:replace, :replace=>"?").encode('UTF-8')
          puts line
        end

        if line =~ /BUILD FAILURE/
          wrong_section_started = true
          #temp_wrong_lines = []
        end

        if line =~ /To see the full stack trace of the error/ && wrong_section_started == true
          wrong_section_started = false
          #wrong_lines << temp_wrong_lines.join
        end
        wrong_lines << line if wrong_section_started
        wrong_mark << line if line =~ /Failed to execute goal/
      end
      [wrong_lines.join, wrong_mark.join]
    end

    def self.gradle_slice(file_array)
      wrong_lines = []
      wrong_section_started = false

      file_array.each do |line|
        if ! line.valid_encoding?
          line = line.encode("UTF-16be", :invalid=>:replace, :replace=>"?").encode('UTF-8')
          puts line
        end

        if line =~ /What went wrong:/
          wrong_section_started = true
          #temp_wrong_lines = []
        end

       if line =~ /Try:/ && wrong_section_started == true
          wrong_section_started = false
          #wrong_lines << temp_wrong_lines.join
        end

        wrong_lines << line if wrong_section_started
      end
      wrong_lines.join
    end


    def self.wrong_message_slice(hash)
      file_array = IO.readlines(hash[:log_file_path])
      file_array.collect! do |line|
        begin
          sub = line.sub(/\r\n?/, "\n")  
        rescue
          sub = line.encode('ISO-8859-1', 'ISO-8859-1').sub(/\r\n?/, "\n")
        end
        sub
      end

      if hash[:use_maven]
        maven_slice, maven_mark = maven_slice(file_array)
        hash[:maven_slice] = maven_slice.length > 0 ? maven_slice : nil
        hash[:maven_mark] = maven_mark.length > 0 ? maven_mark : nil
      end

      if hash[:use_gradle]
        gradle_slice = gradle_slice(file_array)
        hash[:gradle_slice] = gradle_slice.length > 0 ? gradle_slice : nil
      end

      hash.delete :use_ant
      hash.delete :use_maven
      hash.delete :use_gradle
      hash.delete :log_file_path
      @out_queue.enq hash
    end

    def self.thread_init
      @in_queue = SizedQueue.new(30)
      @out_queue = SizedQueue.new(200)

      consumer = Thread.new do
        id = 1001379
        loop do
          hash = nil
          bulk = []
          200.times do
            hash = @out_queue.deq
            break if hash == :END_OF_WORK
            id += 1
            hash[:id] = id
            bulk << WrongSlice.new(hash)
          end
          WrongSlice.import bulk
          break if hash == :END_OF_WORK
       end
      end

      threads = []
      30.times do
        thread = Thread.new do
          loop do
            hash = @in_queue.deq
            break if hash == :END_OF_WORK
            wrong_message_slice hash
          end
        end
        threads << thread
      end
      [consumer, threads]
    end

    def self.scan_log_directory(build_logs_path)
      consumer, threads = thread_init
      Job.where("id >= ? AND (job_state = ? OR job_state = ?)", 5145900, 'errored', 'failed').find_each do |job|
        repo_name = job.repo_name
        job_number = job.job_number
        build_number_int = job.build_number_int
        job_order_number = job.job_order_number
        use_ant = job.ant == 1 ? true : false
        use_maven = job.maven == 1 ? true : false
        use_gradle = job.gradle == 1 ? true : false
        next if use_ant == false && use_maven == false && use_gradle == false
        log_file_path = File.join(build_logs_path, repo_name.sub(/\//, '@'), job_number.sub(/\./, '@') + '.log')
        next if File.exist?(log_file_path) == false
        puts "Scan #{job.id} #{log_file_path}"
        hash = Hash.new
        hash[:repo_name] = repo_name
        hash[:job_number] = job_number
        hash[:build_number_int] = build_number_int
        hash[:job_order_number] = job_order_number
        hash[:use_ant] = use_ant
        hash[:use_maven] = use_maven
        hash[:use_gradle] = use_gradle
        hash[:log_file_path] = log_file_path
        @in_queue.enq hash
      end
   
      30.times do
        @in_queue.enq :END_OF_WORK
      end
      threads.each { |t| t.join }
      @out_queue.enq(:END_OF_WORK)
      consumer.join
      puts "Scan Over"
    end

    def self.run(build_logs_path)
      Thread.abort_on_exception = true
      scan_log_directory build_logs_path
    end

    def self.update(build_logs_path)
      WrongSlice.where("id > ?", 271271).find_each do |wrong|
        repo_name = wrong.repo_name
        job_number = wrong.job_number
        log_file_path = File.join(build_logs_path, repo_name.sub(/\//, '@'), job_number.sub(/\./, '@') + '.log')
        puts "wrong_slice: #{wrong.id} #{log_file_path}"
        file_array = IO.readlines log_file_path
        file_array.collect! do |line|
          begin
            sub = line.sub(/\r\n?/, "\n")  
          rescue
            sub = line.encode('ISO-8859-1', 'ISO-8859-1').sub(/\r\n?/, "\n")
          end
          sub
        end
        job = Job.find_by(repo_name: repo_name, job_number: job_number)

        if job.maven == 1
          maven_slice, maven_mark = maven_slice(file_array)
          wrong.maven_slice = maven_slice.length > 0 ? maven_slice : nil
          wrong.maven_mark = maven_mark.length > 0 ? maven_mark : nil
        end

        if job.gradle == 1
          gradle_slice = gradle_slice(file_array)
          wrong.gradle_slice = gradle_slice.length > 0 ? gradle_slice : nil
        end
        wrong.save
      end
    end

    def self.has_failed_test
      maven_mark = 'test failure'
      gradle_mark = 'failing test'
      WrongSlice.where("id > ?", 475998).find_each do |wrong|
        puts wrong.id
        maven = wrong.maven_mark
        gradle = wrong.gradle_slice
        flag = 0
        if maven && maven.include?(maven_mark)
          flag = 1
        end
        if gradle && gradle.include?(gradle_mark)
          flag = 1
        end
        wrong.test_failed = flag
        wrong.save
      end
    end

    def self.compilation_error_phase
      maven_production = /maven-compiler-plugin:[.\d]+:compile/
      maven_test = /maven-compiler-plugin:[.\d]+:testCompile/
      gradle_production = /:compileJava/
      gradle_test = /:compileTestJava/
      CompilationSlice.select(:id, :repo_name, :job_number).where("id > ?", 101480).find_each do |slice|
        puts slice.id
        repo_name = slice.repo_name
        job_number = slice.job_number
        wrong_slice = WrongSlice.find_by(repo_name: repo_name, job_number: job_number)

        production = 0
        test = 0

        maven_mark = wrong_slice.nil? ? nil : wrong_slice.maven_mark
        gradle_slice = wrong_slice.nil? ? nil : wrong_slice.gradle_slice
        if maven_mark
          production = 1 if maven_mark =~ maven_production
          test = 1 if maven_mark =~ maven_test
        end

        if gradle_slice
          production = 1 if gradle_slice =~ gradle_production
          test = 1 if gradle_slice =~ gradle_test
        end
        slice.production = production
        slice.test = test
        slice.save
      end
    end

    def self.compilation_error_task
      hash = Hash.new(0)
      i = 0
      gradle_regexp = /Execution failed for task '+(:[^:\s]+)*:([^:\s]+)'+/
      maven_regexp = /Failed to execute goal ([^:\s]+):([^:\s]+):([^:\s]+):(\S+) /
      CompilationSlice.select(:id, :repo_name, :job_number).where("id > ?", 0).find_each do |slice|
        i += 1
        #puts slice.id
        repo_name = slice.repo_name
        job_number = slice.job_number
        wrong_slice = WrongSlice.find_by(repo_name: repo_name, job_number: job_number)
        puts hash if i % 10000 == 0
        maven_mark = wrong_slice.nil? ? nil : wrong_slice.maven_mark
        gradle_slice = wrong_slice.nil? ? nil : wrong_slice.gradle_slice

        if maven_mark
          maven_mark = maven_mark.gsub(/\e\[\d*m/, '')
          m = maven_regexp.match(maven_mark)
          if m
            slice.task_name = m[4]
            hash[m[4]] += 1
          else
            p slice.id
            p maven_mark
          end
        end

        if gradle_slice
          gradle_slice = gradle_slice.gsub(/\e\[\d*m/, '')
          m = gradle_regexp.match(gradle_slice)
          if m
            slice.task_name = m[2]
            hash[m[2]] += 1 
          else
            p slice.id
            p gradle_slice
          end
        end
        slice.save
      end
      puts hash
    end

    def self.passed_task_name
      gradle_regexp = /Execution failed for task '+(:[^:\s]+)*:([^:\s]+)'+/
      maven_regexp = /Failed to execute goal ([^:\s]+):([^:\s]+):([^:\s]+):(\S+) /
      Job.where("id > 5118957 AND job_state = 'passed' AND compilation_error = 1").find_each do |job|
        repo_name = job.repo_name.gsub('/', '@')
        job_number = job.job_number.gsub('.', '@')
        file_path = File.expand_path(File.join('..', '..', '..', 'bodyLog2', 'build_logs', repo_name, job_number + '.log'), File.dirname(__FILE__))
        begin
          lines = IO.readlines(file_path).reverse!
        rescue
          p "#{job.id} #{repo_name} #{job_number} does not exist"
          next
        end
        task_name = nil
        lines.each do |line|
          s = line.gsub(/\e\[\d*m/, '')
          m = maven_regexp.match(s)
          if m
            task_name = m[4]
          end

          m = gradle_regexp.match(s)
          if m
            task_name = m[2]
          end

          if task_name
            p "#{job.id} #{repo_name} #{job_number} #{task_name}"
            break
          end
          job.task_name = task_name
          job.save
        end

      end
    end

  end
end
=begin
{"compile"=>78400, "compileJava"=>33398, "testCompile"=>29667, "compileDebug"=>19, "compileGroovy"=>247, "compileTestGroovy"=>287, "compileAstGroovy"=>1, "test"=>4160, "verify"=>49, "yarn"=>49, "npm"=>84, "java"=>2, "deploy"=>16, "enforce"=>70, "compileTestJava"=>9733, "decompileJar"=>1, "compileTestFixturesGroovy"=>2, "compileIntegTestGroovy"=>10, "compileDebugAndroidTestJavaWithJavac"=>398, "compileDebugJavaWithJavac"=>2496, "connectedDebugAndroidTest"=>72, "single"=>8, "start"=>4, "build"=>10, "compileDebugJava"=>841, "compileDebugUnitTestJava"=>149, "compileTestDebugJava"=>170, "compileRelease"=>11, "npmInstall"=>2, "checkstyleMain"=>46, "site"=>29, "compileFunctionalJava"=>2, "compileFunctionalGroovy"=>1, "check"=>311, "compileDebugUnitTestJavaWithJavac"=>840, "compileReleaseJavaWithJavac"=>871, "compileDebugUnitTestKotlin"=>25, "install-file"=>2, "compileDebugTestJava"=>95, "transformClassesWithDexForDebug"=>1, "lint"=>36, "descriptor"=>1, "revision"=>3, "unpack"=>3, "compileFreeDebugJava"=>10, "compileFreeDebugTestJava"=>10, "compilePlayBetaDebugJava"=>15, "compileFreeDebugAndroidTestJava"=>5, "compileBetaDebugJava"=>3, "compileApiJava"=>524, "compileFreshInstallTestGroovy"=>2, "resources"=>5, "read-project-properties"=>183, "findbugs"=>2, "migrate"=>8, "compileDebugAndroidTestJava"=>36, "compileCsaccessTestJava"=>2, "compileFossDebugJava"=>3, "compileTestScala"=>16, "compileIntegrationTestJava"=>21, "compileNoAnalyticsWithCloudDebugJava"=>19, "compileNoAnalyticsNoCloudDebugJava"=>1, "compileDevelopDebugJavaWithJavac"=>2, "xjc"=>2, "compileJpaModelgenJava"=>1, "compileInappDebugUnitTestJavaWithJavac'"=>14, "kaptInappDebugKotlin'"=>4, "compilePremiumDebugKotlin'"=>1, "compileInappDebugUnitTestKotlin'"=>2, "compileJava'"=>271, "compileInappDebugKotlin'"=>1, "compileDevreleaseJavaWithJavac'"=>2, "compileDebugJavaWithJavac'"=>8, "compileBenchmarkJava'"=>5, "compileTestJava'"=>97, "compileDebugJava'"=>1, "test'"=>1, "compileGroovy'"=>2, "compileTestGroovy'"=>8, "compileKotlin'"=>14, "compileFishingSkillMainKotlin'"=>1, "compileConsumablesTestKotlin'"=>2, "compileFishingSkillScripts'"=>3, "compileTestKotlin'"=>9, "compileScripts'"=>13, "compileEntityLookupTestKotlin'"=>2, "compilePlayerActionScripts'"=>2, "compileDebugUnitTestJavaWithJavac'"=>1, "compileReleaseJava'"=>13, "compileDebugAndroidTestJava'"=>1, "compileNoAnalyticsDebugJava"=>5, "compileNoAnalyticsDebugJavaWithJavac"=>75, "compileInternalDebugJavaWithJavac"=>12, "compileInternalDebugUnitTestJavaWithJavac"=>5, "compileTest"=>7, "compileNoAnalyticsDebugTestJava"=>1, "bundle"=>3, "process"=>9, "integrationTest"=>125, "run"=>5, "compileItestJava"=>34, "compileScala"=>65, "compileExampleJava"=>11, "compileDefaultFlavorDebugJava"=>8, "copy"=>1, "generate"=>3, "compileDebugKotlin"=>206, "compileJavaExampleDebugAndroidTestJavaWithJavac"=>6, "generateQueryDSL"=>5, "checkstyle"=>14, "war"=>3, "exec"=>26, "sonar"=>10, "test-compile"=>20, "compileUtilsJava"=>10, "compileClientJava"=>1, "proguard"=>3, "sort"=>1, "shade"=>1, "artemis"=>1, "compileDebugUnitTestGroovy"=>1, "compileAjcJava"=>3, "generate-sources"=>22,"izpack"=>4, "transformClassesAndResourcesWithProguardForRelease"=>1, "compileReleaseJava"=>138, "connectedAndroidTest"=>4, "testDebug"=>1, "check-file-header"=>2, "generateJavahHeaders"=>3, "compileFroyoReleaseJavaWithJavac"=>1, "compileLatestReleaseJava"=>6, "compileSass"=>4, "compileBetaReleaseJavaWithJavac"=>6, "compileBetaDebugJavaWithJavac"=>35, "compileBetaTravisJavaWithJavac"=>3, "compileVanillaDebugJavaWithJavac"=>58, "compileVanillaReleaseJavaWithJavac"=>435, "compileVanillaDebugJava"=>108, "kaptVanillaReleaseKotlin"=>15, "kaptGenerateStubsVanillaReleaseUnitTestKotlin"=>17, "compileVanillaReleaseKotlin"=>1, "compileBetaDebugAndroidTestJava"=>1, "integTest"=>10, "junitPlatformTest"=>1, "compileIntegTestJava"=>6, "compileLightningLiteDebugKotlin"=>4, "compileLightningPlusDebugJava"=>46, "compileLightningLiteReleaseJavaWithJavac"=>7, "compileLightningLiteDebugJavaWithJavac"=>6, "compileLightningLiteDebugJava"=>3, "compileObaAmazonDebugJavaWithJavac"=>12, "compileObaGoogleDebugJavaWithJavac"=>16, "compileObaGoogleDebugJava"=>3, "compileAmazonDebugJava"=>5, "compileObaGoogleDebugAndroidTestJava"=>1, "compileGoogleDebugJava"=>2, "compileGoogleplayDebugJavaWithJavac"=>14, "samplesJadxCompile"=>3, "buildMaven"=>1, "compileTestDummiesJava"=>1, "compileJmhJava"=>13, "compileDatabaseTestJava"=>1, "compileTestKotlin"=>82, "compileJdk7Java"=>16, "compileJdk9Java"=>5, "compileJdk8Java"=>1, "compileSlowtestJava"=>24, "compileAlphaJavaWithJavac"=>8, "compileKotlin"=>294, "compileDevDebugJavaWithJavac"=>42, "compileProdReleaseJavaWithJavac"=>5, "compileAlphaJava"=>11, "compileProdAlphaJavaWithJavac"=>1, "compileDevDebugUnitTestJavaWithJavac"=>19, "execute"=>1, "compileTestFunctionalJava"=>1, "compileGithubDebugKotlin"=>5, "compileGithubDebugAndroidTestKotlinAfterJava"=>3, "kaptGenerateStubsGithubDebugUnitTestKotlin"=>7, "kaptGithubDebugKotlin"=>2, "compileGithubDebugJavaWithJavac"=>29, "compileGithubDebugUnitTestKotlin"=>3, "compileGithubDebugKotlinAfterJava"=>1, "compileReleaseUnitTestJavaWithJavac"=>48, "compileOfflineDebugJavaWithJavac"=>5, "generateAsync"=>1, "create"=>5, "compileSimpleDebugJava"=>5, "_compileSimpleDebugJava"=>1, "compileSimpleDebugJavaWithJavac"=>4, "compileSupportDebugJava"=>7, "compileSupportDebugTestJava"=>4, "compileDebugAndroidTestKotlin"=>65, "kaptGenerateStubsDebugAndroidTestKotlin"=>7, "kaptDebugAndroidTestKotlin"=>1, "kaptGenerateStubsDebugUnitTestKotlin"=>10, "compileGoogleDebugJavaWithJavac"=>14, "compileExtendedrunnerReleaseJava"=>19, "compileExtendedDebugJava"=>5, "compileLicenseSrcJava"=>1, "ajc"=>1, "install"=>28, "compileclient"=>3, "compileStagingDebugJava"=>17, "compileProductDebugJava"=>1, "compileStagingDebugTestJava"=>1, "_compileDebugJava"=>70, "compileIntTestJava"=>3, "invoke"=>7, "compileFdroidReleaseJavaWithJavac"=>7,"compileFdroidUnittestJava"=>5, "jar"=>14, "compileUnittestJava"=>11, "compileTestGithubUnittestJava"=>14, "compileTestGithubLbdevUnittestJava"=>1, "compileTestUnittestJava"=>3, "compileGithubUnittestJava"=>4, "licenseMain"=>2, "compileNoMapsNoAnalyticsForFDroidDebugTestJava"=>4, "compileNoMapsNoAnalyticsForFDroidDebugJava"=>5, "javadoc"=>12, "compileUnsigneddebugJavaWithJavac"=>6, "compileFossDebugJavaWithJavac"=>7, "compilePlayDebugAndroidTestJavaWithJavac"=>1,"compileBetaJava"=>23, "compileBetaJavaWithJavac"=>8, "precompile"=>4, "spotlessJava"=>22, "functionalTest"=>4, "compileInternalReleaseJava"=>4, "compileInternalDebugJava"=>6, "compileInternalReleaseJavaWithJavac"=>2, "_compileReleaseJava"=>2, "compileAndroid"=>5, "compileDefaultFlavorDebugJavaWithJavac"=>1, "compileTestDefaultFlavorDebugJava"=>1, "add-source"=>7, "report"=>66, "copy-dependencies"=>1, "compileBasicDebugJava"=>50, "compileBasicDebugJavaWithJavac"=>41, "compileFdroidDebugTestJava"=>3, "compileFdroidDebugJava"=>26, "compilePlaystoreDebugJavaWithJavac"=>8, "compileFreeReleaseJavaWithJavac"=>23, "compileProductionDebugUnitTestJava"=>2, "compileProductionDebugUnitTestJavaWithJavac"=>2, "compileProductionDebugJavaWithJavac"=>3, "compileTestProductionDebugJava"=>3, "_compileProductionDebugJava"=>1, "compileFreeDebugJavaWithJavac"=>13, "compileSharedJava"=>12, "instrument"=>1, "groovydebugCompile"=>2, "compileAmazonCIJava"=>3, "compileFdroidDebugWithTestCoverageUnitTestJavaWithJavac"=>42, "compileFdroidDebugAndroidTestJavaWithJavac"=>22, "compileFdroidDebugWithTestCoverageJavaWithJavac"=>41, "compileFdroidDebugJavaWithJavac"=>172, "compileFdroidDebugUnitTestJavaWithJavac"=>9, "compileDevDebugUnitTestJava"=>30, "compileProdDebugProguardUnitTestJavaWithJavac"=>16, "compileProdDebugJavaWithJavac"=>80, "compileProdDebugUnitTestJavaWithJavac"=>88, "compileProdDebugProguardJavaWithJavac"=>1, "compileDevDebugJava"=>11, "codenarcMain"=>10, "coveralls"=>15, "codenarcTest"=>3, "compileIntegrationJava"=>19, "compileNormalDebugJavaWithJavac"=>23, "npmPackages"=>1, "_compileDebugTestJava"=>1, "compileKiwixDebugAndroidTestJavaWithJavac"=>6, "compileKiwixReleaseJavaWithJavac"=>16, "compileKiwixDebugJavaWithJavac"=>7, "compileCustomDebugJavaWithJavac"=>1, "compileTestDyvil"=>19, "compileDPFDyvil"=>16, "compileLibraryDyvil"=>36, "compileLibraryJava"=>6, "genLibrary"=>2, "compileGensrcJava"=>9, "compileCompilerJava"=>11, "compileReplJava"=>1, "compileSystemtestJava"=>290, "compileSpeedtestJava"=>9, "compileMadaniReleaseJavaWithJavac"=>5, "compileMadaniReleaseUnitTestJavaWithJavac"=>17, "mergeMadaniReleaseResources"=>1, "compileBetaUnitTestJavaWithJavac"=>4, "compileAdalRDebugJavaWithJavac"=>12, "compileAdalDebugAndroidTestJavaWithJavac"=>3, "compileMsalRDebugJavaWithJavac"=>2, "compileTestDebuggableReleaseJava"=>3, "lintVitalRelease"=>1, "kaptGoogleDebugKotlin"=>38, "compileFdroidDebugKotlin"=>28, "compileGoogleDebugKotlin"=>3, "kaptGoogleReleaseKotlin"=>2, "getQuoter"=>12, "compileEnterpriseDebugJavaWithJavac"=>33, "compileEnterpriseDebugUnitTestJavaWithJavac"=>7, "compilePerfJava"=>1, "replace"=>3, "prepare-agent"=>1, "compileApJava"=>30, "compileJava6Java"=>10, "compilePremiumReleaseJavaWithJavac"=>2, "compileTravisciDebugJavaWithJavac"=>10, "lintVitalTravisciRelease"=>1, "testDebugUnitTest"=>4, "compileCiDebugJavaWithJavac"=>2, "compileTravisDebugJavaWithJavac"=>12, "ndk-build"=>2, "dex"=>1, "compileOldpermissionsDebugJavaWithJavac"=>5, "compileArmeabiDebugJava"=>12, "compileFatDebugAndroidTestJavaWithJavac"=>7, "compileBetaUnitTestJava"=>5, "compileUnitTestJava"=>1, "compileDonateDebugJavaWithJavac"=>1, "compileJavaPoetJava"=>2, "processDebugResources"=>3, "mergeDebugResources"=>3, "compileFernflowerJava"=>4, "compileJavaWithErrorProne"=>6, "compileTestJavaWithErrorProne"=>2, "compileProdDebugTestJava"=>61, "compileProdDebuggableAndroidTestJavaWithJavac"=>10, "compileProdDebugJava"=>18, "compileProdDebugAndroidTestJava"=>3, "testProdDebugUnitTest"=>6, "connectedAndroidTestProdDebug"=>1, "preDexProdDebug"=>1, "compileDevDebuggableAndroidTestJavaWithJavac"=>1, "compileBtctestnetDebugJavaWithJavac"=>8, "compileProductionReleaseJavaWithJavac"=>9, "compileTestnet_lolliReleaseJava"=>3,"compileBtctestnetReleaseJavaWithJavac"=>1, "_compileDebugJavaWithJavac"=>21, "compileDemoDebugJavaWithJavac"=>1, "run-test-suite"=>19, "restNotesSpringDataRestMaven"=>5, "compileReleaseKotlin"=>28, "compileDebugKotlinAfterJava"=>40, "compileTestLiteJava"=>4, "compileTestNanoJava"=>2, "buildCppRuntime"=>14, "compileFullReleaseJavaWithJavac"=>1, "compileFullDebugJavaWithJavac"=>3, "compileMockDebugAndroidTestJavaWithJavac"=>2, "[secure]Compile"=>2, "compileWithVuforiaDebugJavaWithJavac"=>4, "compileVngrsDebugJava"=>1, "update-file-header"=>11, "compileTestExtensionModule"=>10, "attach-descriptor"=>1, "spotlessMisc"=>1, "runMavenBuild"=>1, "compileObfDebugJavaWithJavac"=>90, "compileOpfDebugJavaWithJavac"=>7, "compileObfDebugUnitTestJavaWithJavac"=>9, "compileOpffDebugJavaWithJavac"=>7, "compileOffDebugJavaWithJavac"=>4, "compileFdroidDebugAndroidTestJava"=>7, "kaptFdroidDebugKotlin"=>4, "testFdroidDebugUnitTest"=>1, "compileGoogleplayDebugJava"=>1, "compileSystemTestJava"=>35, "systemTest"=>17, "compileAgentTestJava"=>4, "updateUserOptions"=>2, "compileFlossDebugJavaWithJavac"=>2, "compileGooglePlayDebugUnitTestJavaWithJavac"=>2, "compileV3DebugJava"=>125, "compileV4DebugJavaWithJavac"=>2, "compileReleaseCompileKotlin"=>139, "compileFunctionalTestGroovy"=>4, "compileReleaseKotlinAfterJava"=>18, "compileSnapshotDebugAndroidTestJavaWithJavac"=>1, "generateInstallers"=>5, "compileDevReleaseJavaWithJavac"=>4, "compileQaDebugJavaWithJavac"=>3, "compileGeneratedJava"=>12, "kaptFlossDebugKotlin"=>5, "kaptGenerateStubsFlossDebugUnitTestKotlin"=>5, "compileFlossDebugKotlin"=>2, "compileOklog3TimberDebugKotlin"=>2, "compileOklogDebugJavaWithJavac"=>2, "compileDevNoGPlayDebugUnitTestJavaWithJavac"=>38, "compileDevWithGPlayDebugJavaWithJavac"=>8, "compileProdNoGPlayDebugJavaWithJavac"=>34, "compileWithGPlayDebugJavaWithJavac"=>13, "compileProdWithGPlayDebugJavaWithJavac"=>4, "compileNoGPlayDebugJavaWithJavac"=>5, "compileDevNoGPlayDebugJavaWithJavac"=>9, "compileXApolloDebugJavaWithJavac"=>10, "compileShopifyDebugJavaWithJavac"=>17, "compileApolloDebugJavaWithJavac"=>2, "compileStore360ReleaseJavaWithJavac"=>2, "compileStore360DebugJavaWithJavac"=>4, "compileAcceptanceTestJava"=>30, "runPlainJs"=>1, "compileStandardDebugKotlin"=>13, "kaptGenerateStubsStandardDebugKotlin"=>5, "compileDebugUnitTestGroovyWithGroovyc"=>9, "compileRegularReleaseJavaWithJavac"=>24, "compileRegularDebugAndroidTestJavaWithJavac"=>11, "crowdinUpload"=>2, "compileRegularDebugUnitTestJavaWithJavac"=>1, "compileAppTestDebugJavaWithJavac"=>4, "compileProduct1ReleaseJavaWithJavac"=>6, "compilePlayBinaryScala"=>1, "assemble"=>2, "compileLicenseJava"=>1, "kaptGenerateStubsDevBackendDebugUnitTestKotlin"=>1, "transformDexArchiveWithDexMergerForDebug"=>2, "transformClassesWithDexBuilderForRelease"=>1, "compileNoDepDebugUnitTestJavaWithJavac"=>5, "compileMinSdkIcsDebugJavaWithJavac"=>4, "compileTravisJavaWithJavac"=>1, "installDebug"=>9, "codenarc"=>19, "compileQuerydsl"=>8, "compilePerformanceJavaWithJavac"=>11, "compileDebugAndroidTestGroovy"=>2, "compileCoolapkDebugJavaWithJavac"=>5, "kaptReleaseKotlin"=>4, "compileBetaDebugUnitTestJavaWithJavac"=>102, "kaptGenerateStubsBetaDebugUnitTestKotlin"=>14, "compileBetaDebugAndroidTestJavaWithJavac"=>40, "kaptBetaDebugKotlin"=>5, "kaptDebugKotlin"=>10, "compileAmazonDebugJavaWithJavac"=>12, "transformClassesWithDexBuilderForDebug"=>1, "compileGradleToolingExtensionGroovy"=>2, "compileFlavorDefaultDebugJavaWithJavac"=>19, "rat"=>3, "compileContemporaryReleaseJavaWithJavac"=>14, "integration-test"=>1, "verifyGoogleJavaFormat"=>1, "compileIntegrationTestKotlin"=>1, "compileFocusGeckoReleaseJavaWithJavac"=>8, "compileFocusWebviewUniversalCoverageKotlin"=>7, "compileKlarGeckoBetaKotlin"=>2, "compileKlarGeckoAarch64CoverageJavaWithJavac"=>2, "compileFocusWebviewUniversalBetaJavaWithJavac"=>5, "compileFocusWebviewCoverageJavaWithJavac"=>2, "compileFocusWebviewUniversalBetaUnitTestJavaWithJavac"=>8, "compileFocusGeckoBetaJavaWithJavac"=>27, "compileFocusGeckoBetaUnitTestKotlin"=>9, "compileFocusWebviewUniversalBetaUnitTestKotlin"=>2, "compileKlarGeckoBetaJavaWithJavac"=>3, "compileFocusWebkitBetaJavaWithJavac"=>1, "compileFocusGeckoBetaKotlin"=>8, "compileFocusWebviewUniversalBetaKotlin"=>5, "compileFocusGeckoBetaUnitTestJavaWithJavac"=>5, "compileKlarGeckoAarch64BetaJavaWithJavac"=>4, "compileFocusWebviewUniversalCoverageJavaWithJavac"=>3, "compileFocusWebviewUniversalReleaseJavaWithJavac"=>1, "compileKlarGeckoArmBetaKotlin"=>3, "compileFocusWebviewBetaJavaWithJavac"=>1, "compileAll32DebugJavaWithJavac"=>2, "compileMainDebugJavaWithJavac"=>12, "annotationProcessing"=>3, "compileJcstressJava"=>9, "protoc"=>1, "compileJava9Java"=>4, "script"=>1, "androidJavadocs"=>1, "aggregate"=>12, "compileStarterSourceJava"=>5, "copyTestsFilteringIgnores"=>1, "compilePlayDebugJavaWithJavac"=>7, "compileDevJavaWithJavac"=>4, "compileCommonJava"=>1}
=end