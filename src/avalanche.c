/* avalanche.c
 */
#include "avalanche.h"
#include <stdio.h>
#include <stdlib.h>

void avalanche(hash_f hash, FILE* ins, uint64_t max_iter, matrix_t* results) {}

matrix_t* matrix_alloc(size_t n_rows, size_t n_cols) {
    matrix_t* M = malloc(sizeof(matrix_t));
    M->n_rows = n_rows;
    M->n_cols = n_cols;
    M->vals = calloc(sizeof(double), n_cols * n_rows);
    return M;
}

void matrix_free(matrix_t* M) {
    if (M == NULL)
        return;
    free(M->vals);
    free(M);
    M = NULL;
}

void matrix_fprintf(FILE* fout, const char* format, const matrix_t* M) {
    if (M == NULL)
        return;

    for (size_t r = 0; r < M->n_rows; ++r) {
        for (size_t c = 0; c < M->n_cols; ++c) {
            fprintf(fout, format, MATRIX_GET(M, r, c));
        }
        fprintf(fout, "\n");
    }
}
