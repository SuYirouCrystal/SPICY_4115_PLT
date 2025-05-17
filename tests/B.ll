@str1 = constant [6 x i8] c"false\00"
@str0 = constant [5 x i8] c"true\00"
declare i32 @printf(i8*, ...)
@.fmt_int = constant [4 x i8] c"%d\0A\00"
@.fmt_str = constant [4 x i8] c"%s\0A\00"
define i32 @main() {
  br i1 1, label %if_then0, label %if_else1
  if_then0:
  %strptr3 = getelementptr inbounds [5 x i8], [5 x i8]* @str0, i32 0, i32 0
  call i32 (i8*, ...) @printf(i8* getelementptr inbounds ([4 x i8], [4 x i8]* @.fmt_str, i32 0, i32 0), i8* %strptr3)
  br label %if_end2
  if_else1:
  %strptr4 = getelementptr inbounds [6 x i8], [6 x i8]* @str1, i32 0, i32 0
  call i32 (i8*, ...) @printf(i8* getelementptr inbounds ([4 x i8], [4 x i8]* @.fmt_str, i32 0, i32 0), i8* %strptr4)
  br label %if_end2
  if_end2:
  ret i32 0
}
