
## You Don't Know Jack About Hashing

Hashing is a difficult problem but the challenge doesn't lie where one might think. The Chartbeat Engineering team recently engaged in a friendly competition to produce a hash function that meets the following criterion:

- its return type needs to be 128-bits
- it must avoid collisions on at least one billion ASCII strings of arbitrary length, usually at most one kilobyte in size
- it must be written in JavaScript (ouch!)
- the "minified" (compiled) JavaScript function must be as small as
  possible, idealy under 512 bytes

Almost all discussions of how to design non-cryptographic hash function 
mention two common desired characteristics: avoiding collisions, and 
performance so when we started, most of us thought that the real challenge would be 
creating a lightweight hashing function that could successfully hash 
a billion items quickly because let's face it, a billion is a lot of things. 
It turns out, hashing a billion items without collision is fairly 
trivial but producing said hashes 

First let's go into a little background about hashing functions. 
The challenge of building a good hashing algorithm (or hash function) is
a perenial problem in computer science. Focusing on non-cryptographic
hash functions, however, one is tempted to claim that this problem is solved.
A couple general purpose hash functions are the
[MumurHash](https://code.google.com/p/smhasher/) family and
[CityHash](https://code.google.com/p/cityhash/).

The documentation around each of these is a great place to start reading
to get a sense on the state of the art of non-cryptographic hashing.

By definition, a hash function takes as input
a string of raw bytes, and returns an integer. The "size" of the hash function
refers to the size of its return type. For instance, the `.hashCode()` method
in Java returns a 32-bit integer; 64-bit and 128-bit return types are also
common. Hashing serves many purposes but it is primarily used to quickly
compare or index large sets of data. At Chartbeat, we hash browser strings
along with some other basic information in order to track the behavior
of over 1 billion visitors to our client sites.


## FNV Variant

The obvious first pass for our submission was to start with an existing simple
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

## Victory?
It turns out that our hacky algorithm managed to hash 1 billion unique strings 
without collision and squeezed in at a meager 214 bytes minified and gzipped.
Not bad at all. But before we could celebrate Jerry Gagleman, holding a Doctorate
in Mathematics and all, decided that we should test the robustness the algorithm before
declaring victory. We went about testing this non-crytographic hashing function
by testing it's avalanche characteristics, that is if we flip one bit does it affect
all of the other bits in the string. To put it another way, imagine the bits of the string
that you're hashing are bunch of dominos. When you knock over one domino, at least some
of the other dominos should be be knocked over such that, after reseting the dominos
and retrying this experiment for each and each domino, every item in the set should 
have been affected. When all is said and done, we can create a probabilty map for each
bit representing the likelihood that it will be changed if another bit changes.

The main part of the testing code which tests whether the j-th bit will be affected
if the i-th bit is flipped looks like this:

    for (size_t i_byte = 0; i_byte < key_size; ++i_byte) {
            for (size_t i_bit = 0; i_bit < 8; ++i_bit) {
                size_t row = i_byte * 8 + i_bit;

                // flip the i-th bit of this byte and re-hash
                char i_mask = 0x80 >> i_bit;
                key[i_byte] ^= i_mask;
                hash(key, key_size, htemp);
                key[i_byte] ^= i_mask;

                for (size_t j_word = 0; j_word < hash_words; ++j_word) {
                    for (size_t j_bit = 0; j_bit < 32; ++j_bit) {
                        size_t col = j_word * 32 + j_bit;

                        // test whether hvalue & htemp differ at j-th bit.
                        uint32_t j_mask = 0x80000000 >> j_bit;
                        if ((hvalue[j_word] ^ htemp[j_word]) & j_mask) {
                            double curr = MATRIX_GET(results, row, col);
                            MATRIX_SET(results, row, col, curr + 1);
                        }
                    }
                }
            }
        }
        
## Results 

_insert map of the results_

So it turns out that our lightweight hashing algorithm had some serious problems.
As you can clearly see, there are distinct patterns highlighting the fact that no matter
which bit is flipped, some bits are never affected ultimately making this a poor choice
for a production hashing function.

The overall conclusion is that when having any sort of discussion about non-cryptographic
hashing functions, one must talk not only about performance and size but also the avalanche
characteristics of said function. 
