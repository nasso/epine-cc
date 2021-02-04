#include "my.h"
#include <stdarg.h>
#include <stdio.h>

/* a blatant lie */
int my_printf(const char* fmt, ...)
{
    va_list ap;
    int n = 0;

    va_start(ap, fmt);
    n = vprintf(fmt, ap);
    va_end(ap);
    return n;
}
