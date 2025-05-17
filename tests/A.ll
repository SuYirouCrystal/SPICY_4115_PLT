declare i32 @printf(i8*, ...)
@.fmt_int = constant [4 x i8] c"%d\0A\00"
@.fmt_str = constant [4 x i8] c"%s\0A\00"
define i32 @main() {
  %ptr0 = alloca i32
  store i32 5, i32* %ptr0
  %ptr1 = alloca i32
  %load2 = load i32, i32* %ptr0
  %bin3 = mul i32 2, 3
  %bin4 = add i32 %load2, %bin3
  store i32 %bin4, i32* %ptr1
  %load5 = load i32, i32* %ptr1
  call i32 (i8*, ...) @printf(i8* getelementptr inbounds ([4 x i8], [4 x i8]* @.fmt_int, i32 0, i32 0), i32 %load5)
  ret i32 0
}
