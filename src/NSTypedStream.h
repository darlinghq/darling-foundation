// Typedstream labels and type layout shared by NSArchiver and NSUnarchiver.
#import <Foundation/NSException.h>

static signed char const Long2Label         = -127;     // 0x81
static signed char const Long4Label         = -126;     // 0x82
static signed char const RealLabel          = -125;     // 0x83
static signed char const NewLabel           = -124;     // 0x84
static signed char const NullLabel          = -123;     // 0x85
static signed char const EndOfObjectLabel   = -122;     // 0x86
static signed char const SmallestLabel      = -110;     // 0x92

#define BIAS(x) (x - SmallestLabel)

static unsigned int roundUp(unsigned int size, unsigned int align)
{
   return ((size + align - 1) / align) * align;
}

static const char* skipStructName(const char* str)
{
   const char* type = str;

   while (TRUE)
   {
      switch (*type++)
      {
         case '=':
            return type;
         case '}':
         case '{':
         case ')':
         case '(':
         case 0:
            return str;
      }
   }
}

// This is NOT a duplicate of NSGetSizeAndAlignment. This function just stops after the 1st type it finds.
static const char* sizeofType(const char* type, unsigned int* size, unsigned int* align)
{
   char c = *type++;

#define simpleCase(cc, type) case cc: *size = sizeof(type); *align = __alignof(type); break

   switch (c)
   {
      simpleCase('c', char);
      simpleCase('C', char);
      simpleCase('s', short);
      simpleCase('S', short);
      simpleCase('i', int);
      simpleCase('I', int);
      simpleCase('!', int);
      simpleCase('l', int);
      simpleCase('L', int);
      simpleCase('q', long long);
      simpleCase('Q', long long);
      simpleCase('f', float);
      simpleCase('d', double);
      simpleCase('@', id);
      simpleCase('*', char*);
      simpleCase('%', char*);
      simpleCase(':', SEL);
      simpleCase('#', Class);
      case '[':
      {
         unsigned int count = 0;
         unsigned s, a;

         while ('0' <= *type && *type <= '9')
            count = 10 * count + (*type++ - '0');

         type = sizeofType(type, &s, &a);

         *size = count * roundUp(s, a);
         *align = a;

         c = *type++;
         if (c != ']')
            [NSException raise:NSInvalidArgumentException format:@"Invalid char found in array encoding, expected ], found %c", c];

         break;
      }
      case '(':
      {
         unsigned int unionSize = 0;
         unsigned int unionAlign = 1;

         type = skipStructName(type);

         while (*type != ')')
         {
            unsigned int s, a;

            type = sizeofType(type, &s, &a);

            if (s > unionSize)
               unionSize = s;
            if (a > unionAlign)
               unionAlign = a;
         }

         *size = roundUp(unionSize, unionAlign);
         *align = unionAlign;
         break;
      }
      case '{':
      {
         unsigned int structSize = 0;
         unsigned int structAlign = 1;

         type = skipStructName(type);

         while (*type != '}')
         {
            unsigned int s, a;

            type = sizeofType(type, &s, &a);
            structSize = roundUp(structSize, a);
            structSize += s;
            if (a > structAlign)
               structAlign = a;
         }

         *size = roundUp(structSize, structAlign);
         *align = structAlign;
         break;
      }
      default:
         [NSException raise:NSInvalidArgumentException format:@"typedstream: unsupported type '%c'", c];
   }

#undef simpleCase
    return type;
}

