require 'regular_expression'
module Fdse
  class Property

    def get_key(path, line)
      match = /[\w.]+/.match(line)
      sym = (File.basename(path) + '_' + match[0]).gsub(/\./, '_').to_sym
    end

    def regexp_string(line)
      #line.chomp.strip.sub(/\\n\\/,'').sub(/\\$/,'').gsub(/{[0-9]}|:|;|,|\[|\]|\\u\d+|'|"/,' ').gsub(/(?=[().\[\]])/,"\\").gsub(/\s{2,}/,'[^\n]*').gsub(/\d/,"\d+")
      line.chomp.strip.sub(/\\n\\/,'').sub(/\\$/,'').gsub(/{[0-9]}|:|;|,|\[|\]|\\u\d+|'|"|\(|\)|\.|@/,'  ').gsub(/\s{2,}/,'[^\n]*').gsub(/\d/,"\d+")
    end

    def regexp_strings(properties_file, k)
      index = k - 1
      while properties_file[k] !~ /^$/ && properties_file[k] != nil
        str ||= '^[^\n]*' + regexp_string(properties_file[k]) if k == index+1
        str += '([^\n]*\n[^\n]*){1,3}' + regexp_string(properties_file[k]) if k == index+2
        str += '[^\n]*\n[^\n]*'+regexp_string(properties_file[k]) if k != index+2 && k != index+1
        k += 1
      end
      str += '([^\n]*\n[^\n]*){0,3}[^\n]*\n'
      str.gsub(/(\[\^\\n\]\*|[\s&&[^\n]]){2,}/, '[^\n]*')
    end

    def parse_properties_file(path)
      regexp_hash = Hash.new

      properties_file = IO.readlines(path)
      properties_file.each_with_index do|line,index|
        next unless line.start_with?('compiler')
        sym = get_key(path, line)

        k = index + 1
        str = regexp_strings(properties_file, k)
        regexp_hash[sym] = Regexp.new(str, Regexp::MULTILINE)
      end
      regexp_hash
    end


    def detect_duplication(hash)
      keys = hash.keys
      count_hash = Hash.new(0)
      keys.each do |key|
        count_hash[hash[key]] += 1
      end
      count_hash
    end

    def remove_duplication!(hash)
      count_hash = detect_duplication(hash)
      keys = hash.keys
      keys.reverse_each do |key|
        next if count_hash[hash[key]] == 1
        count_hash[hash[key]] -= 1
        hash.delete key
      end
      hash
    end

    def sort_by_length(hash)
      hash.sort_by { |key, value| value.source.scan(/\w{2,}/).length}.to_h
    end

    def similarity_matrix_initialize(hash)
      similarity_hash = Hash.new
      keys = hash.keys
      keys.each do |sym_a|
        temp_hash = Hash.new
        keys.each do |sym_b|
          temp_hash[sym_b] = 0
        end
        similarity_hash[sym_a] = temp_hash
      end
      similarity_hash
    end

    def regexp_similarity?(regex_a, regex_b)
      flag = false
      flag = true if regex_a =~ (regex_b.source.sub(/\\n$/,'') + "\n")
      flag
    end

    def calculate_similarity_matrix!(hash, similarity_hash)
      similarity_hash.each do |key_a,value|
        value.each_key do |key_b|
          next if key_a == key_b
          next if similarity_hash[key_b][key_a] == 1
          similarity_hash[key_a][key_b] = 1 if regexp_similarity?(hash[key_a], hash[key_b])
        end
      end
    end

    def sum_similarity(hash)
      sum=0
      hash.each_value do |value|
        sum += value
      end
      sum
    end

    def sort_regex_hash(hash, similarity_hash)
      keys = hash.keys
      temp_hash = Hash.new
      stack = []
      similarity_hash.each do |key,value|
        sum = sum_similarity(value)
        stack.push(key) if sum == 0
      end

      while !stack.empty?
        top = stack.pop
        temp_hash[top] = hash[top]
        keys.each do |key|
          if similarity_hash[key][top] != 0
            similarity_hash[key][top] = 0
            stack.push(key) if sum_similarity(similarity_hash[key]) == 0
          end
        end
      end
      temp_hash
    end

    def run
      hash = Hash.new
      properties_files=[]
      (7..9).each { |number| properties_files << File.expand_path(File.join('..', 'assets', 'properties', "openjdk#{number}"), File.dirname(__FILE__))}
      properties_files.each { |file| hash.merge! parse_properties_file(file)}

      remove_duplication! hash

      hash[:zc_apply_given_type] = /^[^\n]*in[^\n]*cannot be applied to given types([^\n]*\n[^\n]*){0,3}[^\n]*\n/m
      hash[:zc_cannot_applied] = /^[^\n]*cannot be applied to([^\n]*\n[^\n]*){0,3}[^\n]*\n/m
      hash[:zc_primitive_cannot_nullable] = /^[^\n]*Primitive types cannot be @Nullable[^\n]*\n/m
      hash[:zc_illegal_character] = /^[^\n]*illegal character([^\n]*\n[^\n]*){0,3}[^\n]*\n/m
      hash[:zc_ambiguous] = /^([^\n]*\n){0,3}[^\n]*is ambiguous for[^\n]*\n/m
      hash[:zc_ambiguous_1] = /^[^\n]*reference to[^\n]*is ambiguous([^\n]*\n[^\n]*){1,3}\n/m
      hash[:zc_ambiguous_2] = /^[^\n]*reference to[^\n]*is ambiguous([^\n]*\n[^\n]*){1,3}?both[^\n]*in[^\n]*and[^\n]*in[^\n]*match([^\n]*\n[^\n]*){1,3}\n/m
      hash[:zc_raw_type] = /^[^\n]*found raw type[^\n]*([^\n]*\n[^\n]*){1,3}?missing type arguments for generic class([^\n]*\n[^\n]*){1,3}\n/m
      hash[:zc_javadoc_comment] = /^[^\n]*missing javadoc comment([^\n]*\n[^\n]*){1,3}\n/m
      hash[:zc_jcannot_find_mapping] = /^[^\n]*Cannot find[^\n]*mapping([^\n]*\n[^\n]*){1,3}\n/m
      hash = sort_by_length hash
      similarity_hash = similarity_matrix_initialize hash
      calculate_similarity_matrix!(hash, similarity_hash)
      sort_regex_hash(hash, similarity_hash)
    end
  end

  def self.test
    i = 0
    Property.new.run.each do |key,value|
      #RegularExpression.create(regex_key: key.to_s, regex_value: value.to_s)
      i += 1
      puts "#{key}"
      puts "#{value}"
      puts
    end
    puts i
  end

end


#Fdse.test

#test
#Fdse::Property.new.test
#test