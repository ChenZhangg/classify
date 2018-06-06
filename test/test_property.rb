require 'test/unit'
require 'fdse/property'
class TestProperty < Test::Unit::TestCase

  def setup
    @property = Fdse::Property.new
  end

  def get_path(filename)
    File.expand_path(File.join('assets', 'input', filename), File.dirname(__FILE__))
  end

  def test_get_key
    assert_equal :openjdk7_compiler_misc_cant_override, @property.get_key('openjdk7', 'compiler.misc.cant.override=\\')
    assert_equal :openjdk8_compiler_err_proc_cant_access_1, @property.get_key('openjdk8', 'compiler.err.proc.cant.access.1=\\')
    assert_equal :openjdk9_compiler_warn_underscore_as_identifier, @property.get_key('openjdk9', 'compiler.warn.underscore.as.identifier=\\')
  end

  def test_regexp_string
    lines = IO.readlines(get_path('regexp_string'))
    assert_equal 'abstract methods cannot have a body', @property.regexp_string(lines[0])
    assert_equal '[^\n]*has already been annotated', @property.regexp_string(lines[1])
    assert_equal '[^\n]*is already defined in[^\n]*', @property.regexp_string(lines[2])
    assert_equal 'a type with the same simple name is already defined by the single-type-import of[^\n]*', @property.regexp_string(lines[3])
    assert_equal 'annotation[^\n]*is missing a default value for the element[^\n]*', @property.regexp_string(lines[4])
    assert_equal '[^\n]*missing in reference', @property.regexp_string(lines[5])
    #s = 'use -source 7 or higher to enable diamond operator'
    #puts s.chomp.strip.sub(/\\n\\/,'').sub(/\\$/,'').gsub(/{[0-9]}|:|;|,|\[|\]|\\u\d+|'|"|\(|\)|\.|@/,'  ').gsub(/\s{2,}/,'[^\n]*').gsub(/\d+/,"\\d+")

  end

  def test_regexp_strings
    lines = IO.readlines(get_path('regexp_strings0'))
    assert_equal '^[^\n]*is abstract[^\n]*cannot be instantiated([^\n]*\n){0,}[^\n]*\n', @property.regexp_strings(lines, 0)
    lines = IO.readlines(get_path('regexp_strings1'))
    assert_equal '^[^\n]*inference variable[^\n]*has incompatible bounds([^\n]*\n){0,3}[^\n]*equality constraints[^\n]*\n[^\n]*lower bounds[^\n]*([^\n]*\n){0,}[^\n]*\n', @property.regexp_strings(lines, 0)
  end

  def test_detect_duplication
    hash = {a: 'zhang', b: 'zhang', c: 'chen', d: 'zhang', f: 'zhu', g: 'ling', h: 'zhu'}
    result = @property.detect_duplication hash
    assert_equal({'zhang' => 3, 'chen' => 1, 'zhu' => 2, 'ling' => 1}, result)
  end

  def test_remove_duplication
    hash = {a: 'zhang', b: 'zhang', c: 'chen', d: 'zhang', f: 'zhu', g: 'ling', h: 'zhu'}
    result = @property.remove_duplication!(hash)
    assert_equal({a: 'zhang', c: 'chen', f: 'zhu', g: 'ling'}, result)
    assert_equal(hash, result)
  end

  def test_sort_by_length
    hash = {a: /zhang chen/, c: /zhu ling yun/,f: /zhu/}
    result = @property.sort_by_length(hash)
    assert_equal({f: /zhu/, a: /zhang chen/, c: /zhu ling yun/,}.flatten, result.flatten)
  end

  def test_similarity_matrix_initialize
    hash = {f: /zhu/, a: /zhang chen/, c: /zhu ling yun/}
    result = @property.similarity_matrix_initialize hash
    expected = {f: {f: 0, a: 0, c: 0}, a: {f: 0, a: 0, c: 0}, c: {f: 0, a: 0, c: 0}}
    assert_equal(expected, result)
  end

  def test_regexp_similarity
    hash = @property.parse_properties_file(get_path('regexp_similarity'))

    assert @property.regexp_similarity?(hash[:regexp_similarity_compiler_misc_descriptor], hash[:regexp_similarity_compiler_misc_descriptor_throws])
    assert_false @property.regexp_similarity?(hash[:regexp_similarity_compiler_misc_descriptor_throws], hash[:regexp_similarity_compiler_misc_descriptor])
    assert  @property.regexp_similarity?(hash[:regexp_similarity_compiler_err_illegal_dot], hash[:regexp_similarity_compiler_err_illegal_underscore])
  end

  def test_sum_similarity
    hash = {a: 2, b: 6, c: 10}
    assert_equal(18, @property.sum_similarity(hash))
  end

  def test_calculate_similarity_matrix
    hash = @property.parse_properties_file(get_path('regexp_similarity'))
    hash = @property.sort_by_length hash
    similarity_hash = @property.similarity_matrix_initialize hash
    @property.calculate_similarity_matrix!(hash, similarity_hash)
    result = @property.sort_regex_hash(hash, similarity_hash)
    #p result
  end

  def test_log_match
    hash = Fdse::Property.new.run
    s = <<~'openmicroscopy/bioformats2179.7'
    [ERROR] /home/travis/build/openmicroscopy/bioformats/components/ome-xml/target/generated-sources/ome/xml/model/MapAnnotation.java:[149,9] update(org.w3c.dom.Element,ome.xml.model.OMEModel) in ome.xml.model.MapPairs cannot be applied to (org.w3c.dom.Element)s
    openmicroscopy/bioformats2179.7
    m = hash[:zc_cannot_applied].match s
    assert_equal s, m[0]

    s = <<~'openzipkin/zipkin6466.1'
    [ERROR] /home/travis/build/openzipkin/zipkin/zipkin-storage/zipkin2_cassandra/src/main/java/zipkin2/storage/cassandra/InsertSpan.java:[52,29] Primitive types cannot be @Nullable
    openzipkin/zipkin6466.1
    m = hash[:zc_primitive_cannot_nullable].match s
    assert_equal s, m[0]

    s = <<~'TwilioDevEd/api-snippets862.1'
    /home/travis/build/TwilioDevEd/api-snippets/testable_snippets/rest/making-calls/template/java/6/src/main/java/Example.java:28: error: illegal character: '#'
    {{#callStatusCallback}}params.add(new BasicNameValuePair("StatusCallback", "{{callStatusCallback}}"));{{/callStatusCallback}}
      ^

    TwilioDevEd/api-snippets862.1
    m = hash[:zc_illegal_character].match s
    assert_equal s, m[0]

    s = <<~'apache/beam5326.4'
    2016-10-29T15:41:10.114 [ERROR] /home/travis/build/apache/incubator-beam/runners/spark/src/main/java/org/apache/beam/runners/spark/io/SourceRDD.java:[220] 
scala.collection.immutable.List.empty();
                                ^^^^^
The method empty() is ambiguous for the type List
    apache/beam5326.4
    m = hash[:zc_ambiguous].match s
    assert_equal s, m[0]

    s = <<~'afollestad/ason90.1'
    [ERROR] /home/travis/build/geoserver/geoserver/src/main/src/main/java/org/geoserver/catalog/impl/AbstractFilteredCatalog.java:[821,15] error: reference to list is ambiguous
[ERROR] 
    T#1 extends CatalogInfo declared in method <T#1>list(Class<T#1>,Filter,Long,Long,SortBy)
    T#2 extends CatalogInfo declared in method <T#2>list(Class<T#2>,Filter,Integer,Integer,SortBy)
    afollestad/ason90.1
    m = hash[:zc_ambiguous_1].match s
    assert_equal s, m[0]

    s = <<~'redisson/redisson487.108'
    [ERROR] /home/travis/build/redisson/redisson/redisson/src/test/java/org/redisson/RedissonLexSortedSetReactiveTest.java:[39,19] error: reference to sync is ambiguous
  both method <V#1>sync(RScoredSortedSetReactive<V#1>) in BaseReactiveTest and method <V#2>sync(RCollectionReactive<V#2>) in BaseReactiveTest match
  where V#1,V#2 are type-variables:
    V#1 extends Object declared in method <V#1>sync(RScoredSortedSetReactive<V#1>)
    V#2 extends Object declared in method <V#2>sync(RCollectionReactive<V#2>)
    redisson/redisson487.108
    m = hash[:zc_ambiguous_2].match s
    assert_equal s, m[0]

    s = <<~'mongodb/mongo-java-driver1749.1'
    /home/travis/build/mongodb/mongo-java-driver/bson/src/main/org/bson/codecs/configuration/mapper/FieldModel.java:23: warning: [rawtypes] found raw type: Codec
    private Codec codec;
            ^
  missing type arguments for generic class Codec<T>
  where T is a type-variable:
    T extends Object declared in interface Codec
    mongodb/mongo-java-driver1749.1
    m = hash[:zc_raw_type].match s
    assert_equal s, m[0]

    s = <<~'OpenCubicChunks/CubicChunks661.1'
    /home/travis/build/OpenCubicChunks/CubicChunks/build/sources/main/java/cubicchunks/asm/mixin/core/common/MixinChunk_Cubes.java:708: warning: @Overwrite is missing javadoc comment
    public boolean isEmptyBetween(int startY, int endY) {
                   ^
    OpenCubicChunks/CubicChunks661.1
    m = hash[:zc_javadoc_comment].match s
    assert_equal s, m[0]

    s = <<~'OpenCubicChunks/CubicChunks723.2'
    /home/travis/build/OpenCubicChunks/CubicChunks/build/sources/main/java/cubicchunks/asm/mixin/core/client/MixinRenderGlobal.java:108: warning: Cannot find method mapping for @At(INVOKE.<target>) 'Lnet/minecraft/client/renderer/chunk/RenderChunk;getChunk(Lnet/minecraft/world/World;)Lnet/minecraft/world/chunk/Chunk;'
    @Inject(method = "renderEntities",
    ^
    OpenCubicChunks/CubicChunks723.2
    m = hash[:zc_cannot_find_mapping].match s
    assert_equal s, m[0]

    s = <<~'grails/grails-core1803.1'
    :grails-test-suite-base:compileGroovyNote: /home/travis/build/grails/grails-core/grails-test-suite-base/src/main/groovy/org/grails/commons/test/AbstractGrailsMockTests.java uses or overrides a deprecated API.
startup failed:
    grails/grails-core1803.1
    m = hash[:zc_uses_deprecated_API].match s
    assert_equal s, m[0]

    s = <<~'geotools/geotools2448.2'
    [ERROR] javac: invalid target release: 1.8
Usage: javac <options> <source files>
use -help for a list of possible options
    geotools/geotools2448.2
    m = hash[:zc_target_release].match s
    assert_equal s, m[0]

    s = <<~'androidannotations/androidannotations438.2'
    [ERROR] /home/travis/build/excilys/androidannotations/[secure]/functional-test-1-5/src/main/java/org/androidannotations/test15/efragment/MyListFragment.java:[84,9] @org.androidannotations.annotations.ItemClick can only have the following parameters: [ [  extending android.widget.AdapterView (optional) ],[  extending java.lang.Object (optional) ],[  extending android.view.View (optional) ],[ int (optional) ],[ long (optional) ], ] in the order above
    androidannotations/androidannotations438.2
    m = hash[:zc_have_parameters].match s
    assert_equal s, m[0]

    s = <<~'google/guice389.3'
    /home/travis/build/google/guice/extensions/jmx/src/com/google/inject/tools/jmx/Manager.java:[56,6] error: cannot find symbol
[ERROR]  class Manager
    google/guice389.3
    m = hash[:zc_cannot_find_symbol].match s
    assert_equal s, m[0]
  end

  def test_run
    refute_nil Fdse::Property.new.run
    #puts Fdse::Property.new.run
  end
end