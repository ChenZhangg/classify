require 'test/unit'
require 'fdse/parse_log_file_mysql'
class TestParseLogFile < Test::Unit::TestCase

  def test_slice
    s = <<~'fossasia/open-event-android4751.1'
    Note: Creating DefaultRealmModule 
<=------------> 9% EXECUTING [1m 0s]> :app:compileFdroidDebugJavaWithJavac<=------------> 9% EXECUTING [1m 1s]<=------------> 9% EXECUTING [1m 2s]<=------------> 9% EXECUTING [1m 3s]<=------------> 9% EXECUTING [1m 4s]<=------------> 9% EXECUTING [1m 5s]<=------------> 9% EXECUTING [1m 6s]e/travis/build/fossasia/open-event-android/android/app/src/main/java/org/fossasia/openevent/activities/SessionDetailActivity.java:365: error: cannot find symboleBuilder.delete(speakers.length()-3,speakers.length()-1); 
^ 
symbol: method length() 
location: variable speakers of type List<Speaker> 
/home/travis/build/fossasia/open-event-android/android/app/src/main/java/org/fossasia/openevent/activities/SessionDetailActivity.java:365: error: cannot find symbol 
speakersNameBuilder.delete(speakers.length()-3,speakers.length()-1); 
^ 
symbol: method length() 
location: variable speakers of type List<Speaker> 
<=------------> 9% EXECUTING [1m 6s]> :app:compileFdroidDebugJavaWithJavac<=------------> 9% EXECUTING [1m 7s]<=------------> 9% EXECUTING [1m 8s]<=------------> 9% EXECUTING [1m 9s]e input files use or override a deprecated API. 
Note: Recompile with -Xlint:deprecation for details. 
Note: /home/travis/build/fossasia/open-event-
    fossasia/open-event-android4751.1
    p s
    p Fdse::ParseLogFile.segment_slice(s.lines)


  end
  
  # Ex:- scope :active, -> {where(:active => true)}
=begin
  def get_path(filename)
    File.expand_path(File.join('assets', 'input', filename), File.dirname(__FILE__))
  end

  def test_use_build_tool
    log_file_path = get_path 'log0'
    assert_equal({gradle: true}, Fdse::ParseLogFile.use_build_tool(log_file_path))
    log_file_path = get_path 'log1'
    assert_equal({maven: true}, Fdse::ParseLogFile.use_build_tool(log_file_path))
  end

  def test_compiler_error_message_slice
    log_file_path = get_path 'log2'
    Fdse::ParseLogFile.compiler_error_message_slice(log_file_path)
    log_file_path = get_path 'log3'
    Fdse::ParseLogFile.compiler_error_message_slice(log_file_path)
  end

  def test_maven_slice
    log_file_path = get_path 'log2'
    expected = File.readlines(get_path('log2expected'))
    assert_equal(expected, Fdse::ParseLogFile.maven_slice(log_file_path))

    log_file_path = get_path 'sk89q@WorldEdit@559@3.log'
    result = Fdse::ParseLogFile.segment_slice(Fdse::ParseLogFile.maven_slice(log_file_path))
    flag = false
    result.each do |segemnt|
      flag = true if segemnt =~ Fdse::ParseLogFile::SEGMENT_BOUNDARY_JAVAC_ERROR
    end
    refute(flag)
  end

  def test_gradle_slice
    log_file_path = get_path 'log3'
    expected = File.readlines(get_path('log3expected'))
    assert_equal(expected, Fdse::ParseLogFile.gradle_slice(log_file_path))

    log_file_path = get_path 'log4'
    expected = File.readlines(get_path('log4expected'))
    assert_equal(expected, Fdse::ParseLogFile.gradle_slice(log_file_path))

    log_file_path = get_path 'log5'
    expected = File.readlines(get_path('log5expected'))
    assert_equal(expected, Fdse::ParseLogFile.gradle_slice(log_file_path))
  end

  def test_encode
    log_file_path = get_path 'encode0'
    Fdse::ParseLogFile.maven_slice(log_file_path)
    Fdse::ParseLogFile.gradle_slice(log_file_path)
  end

  def test_map
    log_file_path = get_path 'sk89q@WorldEdit@803@2@2'
    segment = File.read log_file_path
    assert_equal([:zc_apply_given_type, 1], Fdse::ParseLogFile.map(segment))

    log_file_path = get_path 'sk89q@WorldEdit@803@2@3'
    segment = File.read log_file_path
    assert_equal([:zc_apply_given_type, 1], Fdse::ParseLogFile.map(segment))
  end
=end  
end