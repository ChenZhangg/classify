require 'test/unit'
require 'fdse/parse_log_file'
class TestParseLogFile < Test::Unit::TestCase

  def setup
    #@parser = Fdse::ParseLogFile.new
  end

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
end