#include "box/iproto_constants.h"
#include "box/xrow.h"
#include "trivia/util.h"
#include "fiber.h"
#include "memory.h"

void
cord_on_yield(void) {}

__attribute__((constructor))
static void
setup(void)
{
	memory_init();
	fiber_init(fiber_c_invoke);
}

__attribute__((destructor))
static void
teardown(void)
{
	fiber_free();
	memory_free();
}

int
LLVMFuzzerTestOneInput(const uint8_t *data, size_t size)
{
	const char *p = (const char *)data;
	const char *pe = (const char *)data + size;
	if (mp_check(&p, pe) != 0)
		return -1;

	char *buf = xcalloc(size, sizeof(char));
	if (buf == NULL)
		return 0;
	memcpy(buf, data, size);

	struct xrow_header header;
	const char *pos = mp_encode_uint(buf, size);
	if (!pos)
		return 0;

	const char *end = pos + size;
	if (xrow_header_decode(&header, &pos, end, false) == -1)
		return -1;

	free(buf);

	return 0;
}
