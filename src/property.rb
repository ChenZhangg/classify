class Property
  def stringToRegex(line)
    line.chomp.strip.sub(/\\n\\/,'').gsub(/{[0-9]}|:|;|,|\\u\d+|'|"/,' ').gsub(/(?=[().\[\]])/,"\\").gsub(/\s{2,}/,'[^\n]*').gsub(/\d/,"\d+")
  end

  def stringToValidCharacter(s)
    w=s.gsub(/{[0-9]}/,'').gsub(/[^\w\d'\@()<>:#._=;,]/,'')
  end

  def parseProperty(propertyFile)
    @temp_sym_array=[]
    @temp_regex_hash=Hash.new
    @temp_string_hash=Hash.new
    cpf=IO.readlines(propertyFile)
    cpf.each_with_index do|line,index|
      next unless line.start_with?('compiler')

      match=/[\w.]+/.match(line)
      sym=match[0].gsub(/\./,'_').to_sym
      @temp_sym_array<<sym

      regex_string='^[^\n]*'+stringToRegex(cpf[index+1])

      as=stringToValidCharacter(cpf[index+1])
      k=index+2
      while cpf[k]!~/^$/
        if k==index+2
          regex_string=regex_string+'([^\n]*\n[^\n]*){1,3}?'+stringToRegex(cpf[k])
          as=as+stringToValidCharacter(cpf[k])
        else
          regex_string=regex_string+'[^\n]*\n[^\n]*'+stringToRegex(cpf[k])
          as=as+stringToValidCharacter(cpf[k])
        end
        k+=1
      end
      regex_string=regex_string+'[^\n]*\n'
      if regex_string.scan(/[\w&&[^n]]/).length==0
        @temp_sym_array.pop
        next
      end

      @temp_regex_hash[sym]=Regexp.new(regex_string.gsub(/(\[\^\\n\]\*|[\s&&[^\n]]){2,}/,'[^\n]*'), Regexp::MULTILINE)
      @temp_string_hash[sym]=as
    end
  end

  def insertHashWithHand

    symbol=:cannot_find_symbol_zc0#../../bodyLog2/build_logs/sk89q@WorldEdit/137@2.log
    @temp_sym_array<<symbol
    @temp_regex_hash[symbol]=/^[^\n]*cannot[^\n]*find[^\n]*symbol\n[^\n]*\n/m

    symbol=:incompatible_types_zc0#../../bodyLog2/build_logs/sk89q@WorldEdit/194@3.log
    @temp_sym_array<<symbol
    @temp_regex_hash[symbol]=/^[^\n]*incompatible types[^\n]*\nfound[^\n]*\nrequired[^\n]*\n/m

    symbol=:cannot_implement_zc0#../../bodyLog2/build_logs/sk89q@WorldEdit/194@3.log
    @temp_sym_array<<symbol
    @temp_regex_hash[symbol]=/^[^\n]*in[^\n]*cannot implement[^\n]*in[^\n]*\nfound[^\n]*\nrequired[^\n]*\n/m

    symbol=:cannot_apply_zc0#../../bodyLog2/build_logs/sk89q@WorldEdit/811@1.log
    @temp_sym_array<<symbol
    @temp_regex_hash[symbol]=/^[^\n]*in[^\n]*cannot be applied to given types;\n[^\n]*\n/m

    symbol=:cannot_apply_zc1#../../bodyLog2/build_logs/sk89q@WorldEdit/803@1.log
    @temp_sym_array<<symbol
    @temp_regex_hash[symbol]=/^[^\n]*in[^\n]*cannot be applied to given types;\n/m

    symbol=:cannot_apply_zc2#../../bodyLog2/build_logs/sk89q@WorldEdit/226@2.log
    @temp_sym_array<<symbol
    @temp_regex_hash[symbol]=/^[^\n]*in[^\n]*cannot be applied to[^\n]*\n/m

    symbol=:ref_ambiguous_zc0#../../bodyLog2/build_logs/sk89q@WorldEdit/876@1.log
    @temp_sym_array<<symbol
    @temp_regex_hash[symbol]=/^[^\n]*reference to[^\n]*is ambiguous[^\n]*both[^\n]*in[^\n]*and[^\n]*in[^\n]*match\n/m

    symbol=:without_call_zc0#../../bodyLog2/build_logs/sk89q@WorldEdit/226@2.log
    @temp_sym_array<<symbol
    @temp_regex_hash[symbol]=/^[^\n]*equals\/hashCode implementation but without a call to superclass[^\n]*\n/m

  end


  def detectDuplication
    @duplication_hash=Hash.new
    @count_duplication_hash=Hash.new(0)
    @temp_sym_array.each do |sym|
      @count_duplication_hash[@temp_regex_hash[sym]]+=1
    end
  end

  def removeDuplication
    detectDuplication
    @sym_array=Array.new(@temp_sym_array)
    @temp_sym_array.reverse_each do |sym|
      next if @count_duplication_hash[@temp_regex_hash[sym]]==1
      @count_duplication_hash[@temp_regex_hash[sym]]-=1
      @temp_regex_hash.delete(sym)
      @sym_array.delete(sym)
    end
  end

  def sortByLength
    temp_sym_array=[]
    temp_regex_hash=Hash.new
    temp_regex_hash_length=Hash.new(0)
    @temp_regex_hash.each do |key,hash|
      count=hash.source.scan(/\w{2,}/).length
      temp_regex_hash_length[key]=count
    end

    temp_regex_hash_length.sort{|a,b| a[1]<=>b[1]}.each do |e|
      temp_sym_array<<e[0]
    end

    @sym_array=temp_sym_array
    @sym_array.each do |e|
      temp_regex_hash[e]=@temp_regex_hash[e]
    end
    @temp_regex_hash=temp_regex_hash
  end

  def similarityMatrixInitialize
    @similarity_hash=Hash.new
    @sym_array.each do |sym_a|
      temp_hash=Hash.new
      @sym_array.each do |sym_b|
        temp_hash[sym_b]=0
      end
      @similarity_hash[sym_a]=temp_hash
    end
  end

  def stringSimilarity(str_a,str_b)
    str_b.include?(str_a)
  end

  def regexSimilarity(regex_a,regex_b)
    #if Regexp.new(regex_a.source.sub(/\\n$/,''),Regexp::MULTILINE)=~(regex_b.source)
    regex_a=~(regex_b.source.sub(/\\n$/,'')+"\n")
  end

  def calculateSimilarityMatrix
    @similarity_hash.each do |key_a,hash|
      hash.each_key do |key_b|
        next if key_a==key_b
        @similarity_hash[key_a][key_b]=1 if regexSimilarity(@temp_regex_hash[key_a], @temp_regex_hash[key_b])# || stringSimilarity(@temp_string_hash[key_a], @temp_string_hash[key_b])
      end
    end
  end

  def sumSimilarity(sym)
    sum=0
    @similarity_hash[sym].each_value do |value|
      sum+=value
    end
    sum
  end

  def sortRegexHash
    @regex_hash=Hash.new
    @stack=[]
    @similarity_hash.each do |key,hash|
      sum=sumSimilarity(key)
      @stack.push(key) if sum==0
    end

    while !@stack.empty?
      top=@stack.pop
      @regex_hash[top]=@temp_regex_hash[top]
      @sym_array.each do |sym|
        if @similarity_hash[sym][top]!=0
          @similarity_hash[sym][top]=0
          @stack.push(sym) if sumSimilarity(sym)==0
        end
      end
    end
  end

  def getRegexpHash
    parseProperty('compiler.properties')

    insertHashWithHand

    removeDuplication

    sortByLength
    similarityMatrixInitialize
    calculateSimilarityMatrix
    sortRegexHash
    @regex_hash
  end

end

def test
  Property.new.getRegexpHash.each do |key,value|
    puts "#{key}"
    puts "#{value}"
  end
end
#test
#Property.new.parseProperty('compiler.properties')