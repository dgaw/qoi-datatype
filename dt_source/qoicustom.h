/*
** Customised QOI decoder to allow decoding to a small fixed size buffer.
** Indended to minimise memory usage.
*/

#ifndef QOI_CUSTOM_H
#define QOI_CUSTOM_H

#ifndef QOI_IMPLEMENTATION
// Copy-paste from qoi.h
// Necessary when including qoicustom.h from files other than qoicustom.c
typedef union {
	struct { unsigned char r, g, b, a; } rgba;
	unsigned int v;
} qoi_rgba_t;
#endif

typedef struct {
	qoi_rgba_t index[64]; // Hash table of pixels
	qoi_rgba_t px;        // Last pixel
	int run;              // Bool, use the previous pixel
	int p;                // Current position in the bytes buffer
} qoi_decoding_state;

int qoi_decode_header(const unsigned char *bytes, int size, qoi_desc *desc);
int qoi_init_decoding_state(qoi_decoding_state *state);
int qoi_decode_some(const unsigned char *bytes, int size, int channels,
                    qoi_decoding_state *state, unsigned char *pixels, int pixels_size);

#endif
