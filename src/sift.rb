@maven_error_message='COMPILATION ERROR'
@gradle_error_message='Compilation failed'
puts (Dir.entries('../build_logs/gradle@gradle'))[2..-1].sort_by!{|e| e.sub(/\.log/,'').sub(/@/,'.').to_f}
def regexMatch(line)
  if line=~/is abstract; cannot be instantiated/

  elsif line=~/abstract methods cannot have a body/

  elsif line=~/has already been annotated/

  elsif line=~/is already defined in/

  elsif line=~/a type with the same simple name is already defined by the single-type-import of/

  elsif line=~/a type with the same simple name is already defined by the static single-type-import of/

  elsif line=~/is already defined in this compilation unit/

  elsif line=~/annotation @.+ is missing a default value for the element/

  elsif line=~/annotation @.+ is missing default values for elements/

  elsif line=~/annotation not valid for an element of type/

  elsif line=~/annotation type not applicable to this kind of declaration/

  elsif line=~/annotation value must be an annotation/

  elsif line=~/annotation value must be a class literal/

  elsif line=~/annotation values must be of the form ''name=value''/

  elsif line=~/annotation value not of an allowable type/

  elsif line=~/anonymous class implements interface; cannot have arguments/

  elsif line=~/anonymous class implements interface; cannot have type arguments/

  elsif line=~/anonymous class implements interface; cannot have qualifier for new/

  elsif line=~/cannot inherit from anonymous class/

  elsif line=~/cannot declare both.+and.+in/

  elsif line=~/array dimension missing/

  elsif line=~/array required, but.+found/

  elsif line=~/element value must be a constant expression/

  elsif line=~/bad initializer for/

  elsif line=~/break outside switch or loop/

  elsif line=~/call to.+must be first statement in constructor/

  elsif line=~/in.+cannot be applied to given types/

  elsif line=~/no suitable.+found for/

  elsif line=~/no abstract method found in/

  elsif line=~/multiple non-overriding abstract methods found in/

  elsif line=~/Unexpected @FunctionalInterface annotation/

  elsif line=~/is not a functional interface/

  elsif line=~/invalid functional descriptor for lambda expression/

  elsif line=~/incompatible function descriptors found in/

  elsif line=~/descriptor:/

  elsif line=~/cannot infer functional interface descriptor for/

  elsif line=~/bad intersection type target for lambda or method reference/

  elsif line=~/component type.+is not an interface/

  elsif line=~/invalid.+reference/

  elsif line=~/parameterized qualifier on static method reference/

  elsif line=~/static bound method reference/

  elsif line=~/cannot assign a value to final variable/

  elsif line=~/local variables referenced from.+must be final or effectively final/

  elsif line=~/a lambda expression/

  elsif line=~/an inner class/

  elsif line=~/cannot be dereferenced/

  elsif line=~/''extends'' not allowed for @interfaces/

  elsif line=~/cannot inherit from final/

  elsif line=~/cannot reference.+before supertype constructor has been called/

  elsif line=~/cannot select a static class from a parameterized type/

  elsif line=~/cannot be inherited with different arguments:.+and/

  elsif line=~/''catch'' without ''try''/

  elsif line=~/clashes with package of same name/

  elsif line=~/class, interface or enum declaration not allowed here/

  elsif line=~/constant expression required/

  elsif line=~/continue outside of loop/

  elsif line=~/cyclic inheritance involving/

  elsif line=~/type of element.+is cyclic/

  elsif line=~/call to super not allowed in enum constructor/

  elsif line=~/has no superclass/

  elsif line=~/methods.+from.+and.+from.+are inherited with the same signature/

  elsif line=~/default value only allowed in an annotation type declaration/

  elsif line=~/package.+does not exist/

  elsif line=~/annotation.+is not a valid repeatable annotation/

  elsif line=~/duplicate element ''.+'' in annotation/

  elsif line=~/is not a repeatable annotation type/

  elsif line=~/duplicate annotation:.+is annotated with an invalid @Repeatable annotation/

  elsif line=~/is not a valid @Repeatable, no value element method declared/

  elsif line=~/is not a valid @Repeatable,.+element methods named ''value'' declared/

  elsif line=~/is not a valid @Repeatable: invalid value element/

  elsif line=~/containing annotation type (.+) must declare an element named ''value'' of type/

  elsif line=~/containing annotation type (.+) does not have a default value for element/

  elsif line=~/retention of containing annotation type (.+) is shorter than the retention of repeatable annotation type/

  elsif line=~/repeatable annotation type (.+) is @Documented while containing annotation type (.+) is not/

  elsif line=~/repeatable annotation type (.+) is @Inherited while containing annotation type (.+) is not/

  elsif line=~/containing annotation type (.+) is applicable to more targets than repeatable annotation type (.+)/

  elsif line=~/container.+must not be present at the same time as the element it contains/

  elsif line=~/duplicate class/

  elsif line=~/duplicate case label/

  elsif line=~/duplicate default label/

  elsif line=~/''else'' without ''if''/

  elsif line=~/empty character literal/

  elsif line=~/an enclosing instance that contains.+is required/

  elsif line=~/an enum annotation value must be an enum constant/

  elsif line=~/enum types may not be instantiated/

  elsif line=~/an enum switch case label must be the unqualified name of an enumeration constant/

  elsif line=~/classes cannot directly extend java.lang.Enum/

  elsif line=~/enum types are not extensible/

  elsif line=~/enums cannot have finalize methods/

  elsif line=~/error reading/

  elsif line=~/exception.+has already been caught/

  elsif line=~/exception.+is never thrown in body of corresponding try statement/

  elsif line=~/final parameter.+may not be assigned/

  elsif line=~/auto-closeable resource.+may not be assigned/

  elsif line=~/multi-catch parameter.+may not be assigned/

  elsif line=~/Alternatives in a multi-catch statement cannot be related by subclassing/

  elsif line=~/''finally'' without ''try''/

  elsif line=~/for-each not applicable to expression type/

  elsif line=~/floating point number too large/

  elsif line=~/floating point number too small/

  elsif line=~/generic array creation/

  elsif line=~/a generic class may not extend java.lang.Throwable/

  elsif line=~/Illegal static declaration in inner class/

  elsif line=~/illegal character/

  elsif line=~/unmappable character for encoding/

  elsif line=~/illegal combination of modifiers/

  elsif line=~/illegal reference to static field from initializer/

  elsif line=~/illegal escape character/

  elsif line=~/illegal forward reference/

  elsif line=~/is not available in profile/

  elsif line=~/reference to variable ''.+'' before it has been initialized/

  elsif line=~/self-reference in initializer/

  elsif line=~/self-reference in initializer of variable/

  elsif line=~/illegal generic type for instanceof/

  elsif line=~/illegal initializer for/

  elsif line=~/illegal line end in character literal/

  elsif line=~/illegal non-ASCII digit/

  elsif line=~/illegal underscore/

  elsif line=~/illegal ''.''/

  elsif line=~/illegal qualifier;.+is not an inner class/

  elsif line=~/illegal start of expression/

  elsif line=~/illegal start of statement/

  elsif line=~/illegal start of type/

  elsif line=~/a type with the same simple name is already defined by the static single-type-import of/

  elsif line=~/a type with the same simple name is already defined by the static single-type-import of/

  elsif line=~/a type with the same simple name is already defined by the static single-type-import of/

  elsif line=~/a type with the same simple name is already defined by the static single-type-import of/

  elsif line=~/a type with the same simple name is already defined by the static single-type-import of/

  elsif line=~/a type with the same simple name is already defined by the single-type-import of/

  elsif line=~/a type with the same simple name is already defined by the static single-type-import of/

  elsif line=~/a type with the same simple name is already defined by the static single-type-import of/

  elsif line=~/a type with the same simple name is already defined by the static single-type-import of/

  elsif line=~/a type with the same simple name is already defined by the static single-type-import of/

  elsif line=~/a type with the same simple name is already defined by the static single-type-import of/

  elsif line=~/a type with the same simple name is already defined by the static single-type-import of/

  elsif line=~/a type with the same simple name is already defined by the static single-type-import of/

  elsif line=~/a type with the same simple name is already defined by the static single-type-import of/

  elsif line=~/a type with the same simple name is already defined by the static single-type-import of/

  elsif line=~/a type with the same simple name is already defined by the static single-type-import of/

  elsif line=~/a type with the same simple name is already defined by the static single-type-import of/

  elsif line=~/a type with the same simple name is already defined by the static single-type-import of/

  elsif line=~/a type with the same simple name is already defined by the static single-type-import of/

  elsif line=~/a type with the same simple name is already defined by the static single-type-import of/

  elsif line=~/a type with the same simple name is already defined by the static single-type-import of/

  elsif line=~/a type with the same simple name is already defined by the static single-type-import of/

  elsif line=~/a type with the same simple name is already defined by the single-type-import of/

  elsif line=~/a type with the same simple name is already defined by the static single-type-import of/

  elsif line=~/a type with the same simple name is already defined by the static single-type-import of/

  elsif line=~/a type with the same simple name is already defined by the static single-type-import of/

  elsif line=~/a type with the same simple name is already defined by the static single-type-import of/

  elsif line=~/a type with the same simple name is already defined by the static single-type-import of/

  elsif line=~/a type with the same simple name is already defined by the static single-type-import of/

  elsif line=~/a type with the same simple name is already defined by the static single-type-import of/

  elsif line=~/a type with the same simple name is already defined by the static single-type-import of/

  elsif line=~/a type with the same simple name is already defined by the single-type-import of/

  elsif line=~/a type with the same simple name is already defined by the static single-type-import of/

  elsif line=~/a type with the same simple name is already defined by the static single-type-import of/

  elsif line=~/a type with the same simple name is already defined by the static single-type-import of/

  elsif line=~/a type with the same simple name is already defined by the static single-type-import of/

  elsif line=~/a type with the same simple name is already defined by the static single-type-import of/

  elsif line=~/a type with the same simple name is already defined by the static single-type-import of/

  elsif line=~/a type with the same simple name is already defined by the static single-type-import of/

  elsif line=~/a type with the same simple name is already defined by the static single-type-import of/

  elsif line=~/a type with the same simple name is already defined by the single-type-import of/

  elsif line=~/a type with the same simple name is already defined by the static single-type-import of/

  elsif line=~/a type with the same simple name is already defined by the static single-type-import of/

  elsif line=~/a type with the same simple name is already defined by the static single-type-import of/

  elsif line=~/a type with the same simple name is already defined by the static single-type-import of/

  elsif line=~/a type with the same simple name is already defined by the static single-type-import of/

  elsif line=~/a type with the same simple name is already defined by the static single-type-import of/

  elsif line=~/a type with the same simple name is already defined by the static single-type-import of/

  elsif line=~/a type with the same simple name is already defined by the static single-type-import of/

  elsif line=~/a type with the same simple name is already defined by the single-type-import of/

  elsif line=~/a type with the same simple name is already defined by the static single-type-import of/

  elsif line=~/a type with the same simple name is already defined by the static single-type-import of/

  elsif line=~/a type with the same simple name is already defined by the static single-type-import of/

  elsif line=~/a type with the same simple name is already defined by the static single-type-import of/

  elsif line=~/a type with the same simple name is already defined by the static single-type-import of/

  elsif line=~/a type with the same simple name is already defined by the static single-type-import of/

  elsif line=~/a type with the same simple name is already defined by the static single-type-import of/

  elsif line=~/a type with the same simple name is already defined by the static single-type-import of/

  else

  end

end
