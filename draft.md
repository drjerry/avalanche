
## You Don't Know Jack About Hashing

The challenge of building a good hashing algorithm (or hash function) is
a perenial problem in computer science. Focusing on non-cryptographic
hash functions, however, one is tempted to claim that this problem is solved.
A couple general purpose hash functions are the
[MumurHash](https://code.google.com/p/smhasher/) family and
[CityHash](https://code.google.com/p/cityhash/).

The documentation around each of these is a great place to start reading
to get a sense on the state of the art of non-cryptographic hashing.

Let's back up for a minute. By definition, a hash function takes as input
a string of raw bytes, and returns an integer. The "size" of the hash function
refers to the size of its return type. For instance, the `.hashCode()` method
in Java returns a 32-bit integer; 64-bit and 128-bit return types are also
common.

_(Add more detail about what's the point?)_

Almost all discussions of how to design non-cryptographic hash function mention two common desired characteristics: avoiding collisions, and performance. The Chartbeat Engineering team recently engaged in a friendly competition to produce a hash function that meets the following criterion:

- its return type needs to be 128-bits
- it must avoid collisions on at least one billion ASCII strings of arbitrary   length, usually at most one kilobyte in size
- it must be written in JavaScript (ouch!)
- the "minified" (compiled) JavaScript function must be as small as
  possible, idealy under 512 bytes


## FNV Variant

The obvious first pass for a submission is to start with existing simple
hash function and modify it in some way. Fortunately, not only are many
non-cryptographic functions not only open source, many are public domain.
One such is the [FNV family](http://www.isthe.com/chongo/tech/comp/fnv/).

Pseudo-code for the FNV-1a algorithm is:

    hash = offset_basis
    for each octet_of_data to be hashed
        hash = hash xor octet_of_data
        hash = hash * FNV_Prime
    return hash

Heuristically, the XOR statement inside the loop "mixes" the current hash state
with each successive byte of the input string, and following multiplication
statment "shifts" this state.

In JavaScript, this looks like

    var fnv1a = function(str) {
        var hash = 0x811c9dc5;
        for (var i = 0; i < str.length; i++) {
            hash ^= str.charCodeAt(i);
            hash *= 0x01000193;
        }
        return hash;
    }

The magic constants for `offset_basis` and `FNV_prime` are available directly
from the above link. Sixty-four and 128-bit variants use the same pseudo-code,
and constants for these values are given too. However the details for
implmenting the arithmetic inside the loop get a lot messier; for instance,
the reference C code released by the authors looks like

    /* multiply by the lowest order digit base 2^16 */
    tmp[0] = val[0] * FNV_64_PRIME_LOW;
    tmp[1] = val[1] * FNV_64_PRIME_LOW;
    tmp[2] = val[2] * FNV_64_PRIME_LOW;
    tmp[3] = val[3] * FNV_64_PRIME_LOW;
    /* multiply by the other non-zero digit */
    tmp[2] += val[0] << FNV_64_PRIME_SHIFT;
    tmp[3] += val[1] << FNV_64_PRIME_SHIFT;
    /* propagate carries */
    tmp[1] += (tmp[0] >> 16);
    val[0] = tmp[0] & 0xffff;
    tmp[2] += (tmp[1] >> 16);
    val[1] = tmp[1] & 0xffff;
    val[3] = tmp[3] + (tmp[2] >> 16);
    val[2] = tmp[2] & 0xffff;

just for the inner loop. Converting this to JavaScript will already be a
pain, and in any event it will be putting pressure on the "small as possible"
constraint.

Our thought was, what if we just skip correctness? What if, representing the
has state as an array of integers, we apply the pseudo-code successively to
each element in turn? Hash functions are intended to inject randomness into
data and this _idea_ sounds pretty random. Representing 128-bits as an array
of 4 integers, we get something like

    var fnv_128_attempt = function(str) {
        var h = [0x6295c58d, 0x62b82175, 0x07bb0142, 0x6c62272e];
        for (var i = 0; i < str.length; i++) {
            h[i % 4] ^= str.charCodeAt(i);
            h[i % 4] *= 0x01000193;
        }
        /* returns 4 concatenated hex representations */
        return h[0].toString(16) + h[1].toString(16) + h[2].toString(16) + h[3].toString(16);
    }

