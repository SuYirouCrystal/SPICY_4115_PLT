@str2 = constant [9 x i8] c"Fallback\00"
@str0 = constant [13 x i8] c"This is true\00"
@str1 = constant [15 x i8] c"This won't run\00"
declare i32 @printf(i8*, ...)
@.fmt_int = constant [4 x i8] c"%d\0A\00"
@.fmt_str = constant [4 x i8] c"%s\0A\00"
define i32 @add(i32 %x, i32 %y) {
  %ptr0 = alloca i32
  store i32 %x, i32* %ptr0
  %ptr1 = alloca i32
  store i32 %y, i32* %ptr1
  %load2 = load i32, i32* %ptr0
  %load3 = load i32, i32* %ptr1
  %bin4 = add i32 %load2, %load3
  ret i32 %bin4
}
define i32 @main() {
  %ptr5 = alloca i32
  store i32 3, i32* %ptr5
  %ptr6 = alloca i32
  store i32 4, i32* %ptr6
  %load7 = load i32, i32* %ptr6
  %load8 = load i32, i32* %ptr5
  %call9 = call i32 @add(i32 %load7, i32 %load8)
  call i32 (i8*, ...) @printf(i8* getelementptr inbounds ([4 x i8], [4 x i8]* @.fmt_int, i32 0, i32 0), i32 %call9)
  br i1 1, label %if_then10, label %if_else11
  if_then10:
  %strptr13 = getelementptr inbounds [13 x i8], [13 x i8]* @str0, i32 0, i32 0
  call i32 (i8*, ...) @printf(i8* getelementptr inbounds ([4 x i8], [4 x i8]* @.fmt_str, i32 0, i32 0), i8* %strptr13)
  br label %if_end12
  if_else11:
  br i1 0, label %elif_then14, label %if_else11
  br label %if_end12
  elif_then14:
  %strptr15 = getelementptr inbounds [15 x i8], [15 x i8]* @str1, i32 0, i32 0
  call i32 (i8*, ...) @printf(i8* getelementptr inbounds ([4 x i8], [4 x i8]* @.fmt_str, i32 0, i32 0), i8* %strptr15)
  br label %if_end12
  if_end12:
  %ptr17 = alloca i32
  store i32 0, i32* %ptr17
  br label %loop_cond20
  loop_cond20:
  %ld18 = load i32, i32* %ptr17
  %cmp19 = icmp sle i32 %ld18, 2
  br i1 %cmp19, label %loop_body21, label %loop_end22
  loop_body21:
  %load23 = load i32, i32* %ptr17
  call i32 (i8*, ...) @printf(i8* getelementptr inbounds ([4 x i8], [4 x i8]* @.fmt_int, i32 0, i32 0), i32 %load23)
  %ld24 = load i32, i32* %ptr17
  %inc25 = add i32 %ld24, 1
  store i32 %inc25, i32* %ptr17
  br label %loop_cond20
  loop_end22:
  ret i32 0
}
