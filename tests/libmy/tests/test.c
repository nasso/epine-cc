#include "my.h"
#include <criterion/criterion.h>
#include <criterion/redirect.h>
#include <stdio.h>

Test(my_putstr, it_works, .init = cr_redirect_stdout, .timeout = 1)
{
    my_putstr("hello!\n");
    fflush(stdout);
    cr_assert_stdout_eq_str("hello!\n");
}
