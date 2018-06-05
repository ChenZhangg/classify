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
  end

  def test_regexp_strings
    lines = IO.readlines(get_path('regexp_strings0'))
    assert_equal '^[^\n]*is abstract[^\n]*cannot be instantiated[^\n]*\n', @property.regexp_strings(lines, 0)
    lines = IO.readlines(get_path('regexp_strings1'))
    assert_equal '^[^\n]*inference variable[^\n]*has incompatible bounds([^\n]*\n[^\n]*){1,3}?equality constraints[^\n]*\n[^\n]*lower bounds[^\n]*\n', @property.regexp_strings(lines, 0)
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
    assert(hash[:zc_cannot_applied] =~ s)

    s = <<~'openzipkin/zipkin6466.1'
    [ERROR] /home/travis/build/openzipkin/zipkin/zipkin-storage/zipkin2_cassandra/src/main/java/zipkin2/storage/cassandra/InsertSpan.java:[52,29] Primitive types cannot be @Nullable
    openzipkin/zipkin6466.1
    assert(hash[:zc_primitive_cannot_nullable] =~ s)

    s = <<~'TwilioDevEd/api-snippets862.1'
    /home/travis/build/TwilioDevEd/api-snippets/testable_snippets/rest/making-calls/template/java/6/src/main/java/Example.java:28: error: illegal character: '#'
    {{#callStatusCallback}}params.add(new BasicNameValuePair("StatusCallback", "{{callStatusCallback}}"));{{/callStatusCallback}}
      ^
    TwilioDevEd/api-snippets862.1
    p s
    p hash[:zc_illegal_character]
    m = hash[:zc_illegal_character] =~ s
    p m
  end

  def test_run
    refute_nil Fdse::Property.new.run
    #puts Fdse::Property.new.run
  end
end