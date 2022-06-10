/*
** Customised QOI decoder to allow decoding to a small fixed size buffer.
** Indended to minimise memory usage.
*/

#define QOI_IMPLEMENTATION
#define QOI_NO_STDIO
#include <qoi/qoi.h>
#include "qoicustom.h"

int qoi_decode_header(const unsigned char *bytes, int size, qoi_desc *desc) {
	unsigned int header_magic;
	int p = 0;

	if (bytes == NULL || desc == NULL ||
		size < QOI_HEADER_SIZE + (int)sizeof(qoi_padding)) {
		return 0;
	}

	header_magic = qoi_read_32(bytes, &p);
	desc->width = qoi_read_32(bytes, &p);
	desc->height = qoi_read_32(bytes, &p);
	desc->channels = bytes[p++];
	desc->colorspace = bytes[p++];

	if (
		desc->width == 0 || desc->height == 0 ||
		desc->channels < 3 || desc->channels > 4 ||
		desc->colorspace > 1 ||
		header_magic != QOI_MAGIC ||
		desc->height >= QOI_PIXELS_MAX / desc->width
	) {
		return 0;
	} else {
		return 1;
	}
}

int qoi_init_decoding_state(qoi_decoding_state *state) {
	if (state == NULL) {
		return 0;
	} else {
		QOI_ZEROARR(state->index);
		state->px.rgba.r = 0;
		state->px.rgba.g = 0;
		state->px.rgba.b = 0;
		state->px.rgba.a = 255;
		state->p = QOI_HEADER_SIZE; // Skipping the header
		state->run = 0;
		return 1;
	}
}

int qoi_decode_some(const unsigned char *bytes, int size, int channels,
                    qoi_decoding_state *state, unsigned char *pixels, int pixels_size) {
	int px_pos;
	int chunks_len;

	if (bytes == NULL || pixels == NULL || (channels != 3 && channels != 4) ||
		size < QOI_HEADER_SIZE + (int)sizeof(qoi_padding)) {
		return 0;
	}

	// TODO: Investigate why chunks len doesn't take into account the header
	chunks_len = size - (int)sizeof(qoi_padding);

	for (px_pos = 0; px_pos < pixels_size; px_pos += channels) {
		if (state->run > 0) {
			state->run--;
		}
		else if (state->p < chunks_len) {
			int b1 = bytes[state->p++];

			if (b1 == QOI_OP_RGB) {
				state->px.rgba.r = bytes[state->p++];
				state->px.rgba.g = bytes[state->p++];
				state->px.rgba.b = bytes[state->p++];
			}
			else if (b1 == QOI_OP_RGBA) {
				state->px.rgba.r = bytes[state->p++];
				state->px.rgba.g = bytes[state->p++];
				state->px.rgba.b = bytes[state->p++];
				state->px.rgba.a = bytes[state->p++];
			}
			else if ((b1 & QOI_MASK_2) == QOI_OP_INDEX) {
				state->px = state->index[b1];
			}
			else if ((b1 & QOI_MASK_2) == QOI_OP_DIFF) {
				state->px.rgba.r += ((b1 >> 4) & 0x03) - 2;
				state->px.rgba.g += ((b1 >> 2) & 0x03) - 2;
				state->px.rgba.b += ( b1       & 0x03) - 2;
			}
			else if ((b1 & QOI_MASK_2) == QOI_OP_LUMA) {
				int b2 = bytes[state->p++];
				int vg = (b1 & 0x3f) - 32;
				state->px.rgba.r += vg - 8 + ((b2 >> 4) & 0x0f);
				state->px.rgba.g += vg;
				state->px.rgba.b += vg - 8 +  (b2       & 0x0f);
			}
			else if ((b1 & QOI_MASK_2) == QOI_OP_RUN) {
				state->run = (b1 & 0x3f);
			}

			state->index[QOI_COLOR_HASH(state->px) % 64] = state->px;
		}

		pixels[px_pos + 0] = state->px.rgba.r;
		pixels[px_pos + 1] = state->px.rgba.g;
		pixels[px_pos + 2] = state->px.rgba.b;

		if (channels == 4) {
			pixels[px_pos + 3] = state->px.rgba.a;
		}
	}

	return 1;
}
