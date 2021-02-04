#include "my.h"

#ifdef MY_TESTS
#error "don't test me!! im working just fine!"
#endif

int my_putstr(const char* str)
{
    return my_printf("%s", str);
}
