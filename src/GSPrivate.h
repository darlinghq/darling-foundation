#define GS_MAX_OBJECTS_FROM_STACK 128

/**
 * Macro to manage memory for chunks of code that need to work with
 * arrays of items.  Use this to start the block of code using
 * the array and GS_ENDITEMBUF() to end it.  The idea is to ensure that small
 * arrays are allocated on the stack (for speed), but large arrays are
 * allocated from the heap (to avoid stack overflow).
 */
#if __GNUC__ > 3
__attribute__((unused)) static void GSFreeTempBuffer(void **b)
{
  if (NULL != *b) free(*b);
}
#  define	GS_BEGINITEMBUF(P, S, T) { \
  T _ibuf[GS_MAX_OBJECTS_FROM_STACK];\
  T *P = _ibuf;\
  __attribute__((cleanup(GSFreeTempBuffer))) void *_base = 0;\
  if (S > GS_MAX_OBJECTS_FROM_STACK)\
    {\
      _base = malloc((S) * sizeof(T));\
      P = _base;\
    }
#else
#  define	GS_BEGINITEMBUF(P, S, T) { \
  T _ibuf[(S) <= GS_MAX_OBJECTS_FROM_STACK ? (S) : 0]; \
  T *_base = ((S) <= GS_MAX_OBJECTS_FROM_STACK) ? _ibuf \
    : (T*)NSZoneMalloc(NSDefaultMallocZone(), (S) * sizeof(T)); \
  T *(P) = _base;
#endif

/**
 * Macro to manage memory for chunks of code that need to work with
 * arrays of items.  Use GS_BEGINITEMBUF() to start the block of code using
 * the array and this macro to end it.
 */
#if __GNUC__ > 3
# define	GS_ENDITEMBUF() }
#else
#  define	GS_ENDITEMBUF() \
  if (_base != _ibuf) \
    NSZoneFree(NSDefaultMallocZone(), _base); \
  }
#endif

/**
 * Macro to manage memory for chunks of code that need to work with
 * arrays of objects.  Use this to start the block of code using
 * the array and GS_ENDIDBUF() to end it.  The idea is to ensure that small
 * arrays are allocated on the stack (for speed), but large arrays are
 * allocated from the heap (to avoid stack overflow).
 */
#define	GS_BEGINIDBUF(P, S) GS_BEGINITEMBUF(P, S, id)

/**
 * Macro to manage memory for chunks of code that need to work with
 * arrays of objects.  Use GS_BEGINIDBUF() to start the block of code using
 * the array and this macro to end it.
 */
#define	GS_ENDIDBUF() GS_ENDITEMBUF()

