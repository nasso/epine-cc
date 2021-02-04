CFLAGS = -g3

all: libmy.a
.PHONY: all

libmy_a_SRCS := ./src/my_putstr.c ./src/my_printf.c
libmy_a_OBJS := $(filter %.c,$(libmy_a_SRCS))
libmy_a_OBJS := $(libmy_a_OBJS:.c=.o)
libmy_a_DEPS := $(libmy_a_OBJS:.o=.d)
libmy.a: CPPFLAGS :=
libmy.a: CPPFLAGS += -MD -MP
libmy.a: CPPFLAGS += -Iinclude
libmy.a: CPPFLAGS += -DMY_ALLOW_MALLOC
libmy.a: CPPFLAGS += -DMY_ALLOW_FREE
libmy.a: CPPFLAGS += -DMY_FAKE_MALLOC_FAILURE=16
libmy.a: CFLAGS :=
libmy.a: CFLAGS += -Wall
libmy.a: CFLAGS += -Wextra
libmy.a: CFLAGS += -pedantic
libmy.a: $(libmy_a_OBJS)
	$(AR) rc $@ $(libmy_a_OBJS)
-include $(libmy_a_DEPS)

libmy_so_SRCS := ./src/my_putstr.c ./src/my_printf.c
libmy_so_OBJS := $(filter %.c,$(libmy_so_SRCS))
libmy_so_OBJS := $(libmy_so_OBJS:.c=.o)
libmy_so_DEPS := $(libmy_so_OBJS:.o=.d)
libmy.so: CPPFLAGS :=
libmy.so: CPPFLAGS += -MD -MP
libmy.so: CPPFLAGS += -Iinclude
libmy.so: CPPFLAGS += -DMY_ALLOW_MALLOC
libmy.so: CPPFLAGS += -DMY_ALLOW_FREE
libmy.so: CPPFLAGS += -DMY_FAKE_MALLOC_FAILURE=16
libmy.so: CFLAGS :=
libmy.so: CFLAGS += -fPIC
libmy.so: CFLAGS += -Wall
libmy.so: CFLAGS += -Wextra
libmy.so: CFLAGS += -pedantic
libmy.so: LDLIBS :=
libmy.so: LDFLAGS :=
libmy.so: LDFLAGS += -shared
libmy.so: $(libmy_so_OBJS)
	$(CC) -o $@ $(libmy_so_OBJS) $(LDFLAGS) $(LDLIBS)
-include $(libmy_so_DEPS)

unit_tests_SRCS := tests/test.c
unit_tests_OBJS := $(filter %.c,$(unit_tests_SRCS))
unit_tests_OBJS := $(unit_tests_OBJS:.c=.o)
unit_tests_DEPS := $(unit_tests_OBJS:.o=.d)
unit_tests $(unit_tests_OBJS): libmy.a
unit_tests: CPPFLAGS :=
unit_tests: CPPFLAGS += -MD -MP
unit_tests: CPPFLAGS += -Iinclude
unit_tests: CPPFLAGS += -DMY_TESTS
unit_tests: CFLAGS :=
unit_tests: LDLIBS :=
unit_tests: LDLIBS += -lmy
unit_tests: LDLIBS += -lcriterion
unit_tests: LDFLAGS :=
unit_tests: LDFLAGS += -L.
unit_tests: $(unit_tests_OBJS)
	$(CC) -o $@ $(unit_tests_OBJS) $(LDFLAGS) $(LDLIBS)
-include $(unit_tests_DEPS)

tests_run: unit_tests
	./unit_tests
.PHONY: tests_run

clean:
	$(RM) $(libmy_a_DEPS) $(libmy_a_OBJS) $(libmy_so_DEPS) $(libmy_so_OBJS) $(unit_tests_DEPS) $(unit_tests_OBJS)
.PHONY: clean

fclean:
	$(RM) $(libmy_a_DEPS) $(libmy_a_OBJS) $(libmy_so_DEPS) $(libmy_so_OBJS) $(unit_tests_DEPS) $(unit_tests_OBJS)
	$(RM) libmy.a libmy.so unit_tests
.PHONY: fclean

re: fclean all
.PHONY: re
