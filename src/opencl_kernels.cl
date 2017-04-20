#define IS_BOUNDS(val, bound) ((val) >= (0) && (val) < (bound))

#define SK_SIZE 3

constant float min_R = 200.f;
constant int min_index = 2;
constant float R_inc_dec = 0.05f;
constant int R_scale = 5;
constant int R_lower = 10;
constant int T_lower = 2;
constant float T_dec = 0.05f;
constant int T_inc = 1;
constant int T_upper = 200;

constant float alpha = 10.f;
constant float beta = 1.f;

constant float Gy[SK_SIZE * SK_SIZE] = {-1.f, -2.f, -1.f, 0.f, 0.f,
                                        0.f,  1.f,  2.f,  1.f};
constant float Gx[SK_SIZE * SK_SIZE] = {-1.f, 0.f,  1.f, -2.f, 0.f,
                                        2.f,  -1.f, 0.f, 1.f};

kernel void fill_T_R(global float *oT, global float *oR, const uint width,
                     const uint height, const uint T_lower, const uint R_lower)
{
    int ii = get_global_id(0); // == get_global_id(0);
    int jj = get_global_id(1); // == get_global_id(1);
    int2 coord = (int2)(get_global_id(0), get_global_id(1));
    /* if (IS_BOUNDS(coord.x, width) && IS_BOUNDS(coord.y, height)) */
    {
        oT[jj * width + ii] = T_lower;
        oR[jj * width + ii] = R_lower;
    }
}
kernel void average(global float2 *Im, const uint width, const uint height,
                    global float *avrg_i)
{
    int ii = get_global_id(0); // == get_global_id(0);
    int jj = get_global_id(1); // == get_global_id(1);
    int2 coords = (int2)(ii, jj);

    /* if (IS_BOUNDS(ii * jj, width * height)) */
    {
        *avrg_i += Im[jj * width + ii].y;
    }
}

kernel void magnitude(global uchar *src, const uint width, const uint height,
                      global float2 *des)
{
    int ii = get_global_id(0); // == get_global_id(0);
    int jj = get_global_id(1); // == get_global_id(1);
    int2 coords = (int2)(ii, jj);

    float gx_val = 0.f;
    float gy_val = 0.f;

    const int half_sk_size = SK_SIZE / 2;
    for (int fi = -half_sk_size; fi <= half_sk_size; fi++)
    {

        for (int fj = -half_sk_size; fj <= half_sk_size; fj++)
        {
            const int skpos = (jj + fj) * width + ii + fi;
            if (IS_BOUNDS(ii + fi, width) && IS_BOUNDS(jj + fj, height))
            {
                const float src_val = src[skpos] / 256.f;
                gx_val += src_val *
                          Gx[(fi + half_sk_size) * SK_SIZE + fj + half_sk_size];
                gy_val += src_val *
                          Gy[(fi + half_sk_size) * SK_SIZE + fj + half_sk_size];
            }
        }
    }

    /* if (IS_BOUNDS(ii * jj, width * height)) */
    {
        const float gxx = gx_val * gx_val;
        const float gyy = gy_val * gy_val;

        const float mag = sqrt(gxx + gyy);
        const float i_val = src[jj * width + ii];
        des[jj * width + ii].x = i_val;
        des[jj * width + ii].y = mag;
    }
}

inline float pbas_distance(float I_i, float I_m, float B_i, float B_m,
                           float alpha, float avarage_m)
{
    float Im_diff = abs_diff((int)(I_m), (int)(B_m));
    float Ii_diff = abs_diff((int)(I_i), (int)(B_i));

    float res = (alpha / avarage_m) * Im_diff + Ii_diff;
    return res;
}

kernel void pbas_part1(global float2 *feature, const uint width,
                       const uint height, global float *R, global float *D,
                       global float2 *model, global uint *index_r,
                       const float average_mag)
{
    int idX = get_local_id(0);
    int idY = get_local_id(1);
    int ii = get_global_id(0); // == get_global_id(0);
    int jj = get_global_id(1); // == get_global_id(1);
    int2 coords = (int2)(ii, jj);
    int index_d = index_r[jj * width + ii];
    if (index_d < min_index)
    {
        const float I_i = feature[jj * width + ii].x;
        const float I_m = feature[jj * width + ii].y;

        const float r_val = R[jj * width + ii];

        const float B_i = model[jj * width + ii].x;
        const float B_m = model[jj * width + ii].y;

        const float diff =
            pbas_distance(I_i, I_m, B_i, B_m, alpha, average_mag);

        /* if (IS_BOUNDS(ii * jj, width * height)) */
        {

            if (diff < r_val)
            {
                if (diff < min_R)
                {
                    D[jj * width + ii] = diff;
                }
                index_d++;
            }
        }
    }

    index_r[jj * width + ii] = index_d;
}

unsigned int lfsr113_Bits(global uint *seed)
{

    // enum { A = 4294883355U };
    // uint x = (*seed).x, c = (*seed).y;  // Unpack the state
    // uint res = x^c;                     // Calculate the result
    // uint hi = mul_hi(x, A);              // Step the RNG
    // x = x*A + c;
    // c = hi + (x<c);
    //*seed = (uint2)(x, c);               // Pack the state back up
    // return res;                       // Return the next result

    *seed = (*seed * 1103515245U + 12345U) & 0x7fffffffU;
    return *seed;

    // unsigned int z1 = *seed, z2 = 1313245, z3 = *seed, z4 = 12345;
    // unsigned int b;
    // b = ((z1 << 6) ^ z1) >> 13;
    // z1 = ((z1 & 4294967294U) << 18) ^ b;
    // b = ((z2 << 2) ^ z2) >> 27;
    // z2 = ((z2 & 4294967288U) << 2) ^ b;
    // b = ((z3 << 13) ^ z3) >> 21;
    // z3 = ((z3 & 4294967280U) << 7) ^ b;
    // b = ((z4 << 3) ^ z4) >> 12;
    // z4 = ((z4 & 4294967168U) << 13) ^ b;
    //*seed = abs((z1 ^ z2 ^ z3 ^ z4));
    // return *seed;
}

global float2 *choose_m(global uint *seed, const uint model_size,
                        global float2 *M0, global float2 *M1, global float2 *M2,
                        global float2 *M3, global float2 *M4, global float2 *M5,
                        global float2 *M6, global float2 *M7, global float2 *M8,
                        global float2 *M9, global float2 *M10,
                        global float2 *M11, global float2 *M12,
                        global float2 *M13, global float2 *M14,
                        global float2 *M15, global float2 *M16,
                        global float2 *M17, global float2 *M18,
                        global float2 *M19)
{
    global float2 *mi = M0;
    uint rand_m_for_pixel = lfsr113_Bits(seed) % model_size;

    switch (rand_m_for_pixel)
    {
    case 0:
        mi = M0;
        break;
    case 1:
        mi = M1;
        break;
    case 2:
        mi = M2;
        break;
    case 3:
        mi = M3;
        break;
    case 4:
        mi = M4;
        break;
    case 5:
        mi = M5;
        break;
    case 6:
        mi = M6;
        break;
    case 7:
        mi = M7;
        break;
    case 8:
        mi = M8;
        break;
    case 9:
        mi = M9;
        break;
    case 10:
        mi = M10;
        break;
    case 11:
        mi = M11;
        break;
    case 12:
        mi = M12;
        break;
    case 13:
        mi = M13;
        break;
    case 14:
        mi = M14;
        break;
    case 15:
        mi = M15;
        break;
    case 16:
        mi = M16;
        break;
    case 17:
        mi = M17;
        break;
    case 18:
        mi = M18;
        break;
    case 19:
        mi = M19;
        break;
    }

    return mi;
}

// NOTE model in range [0 ... model_size]
kernel void pbas_part2(
    global float2 *feature, const uint width, const uint height,
    global float *R, global float *T, global uint *index_r,
    const uint min_index, const uint index_l, const uint model_size,
    global uchar *mask, global float *avrg_d, global uint *rand_n,
    global float2 *M0, global float2 *M1, global float2 *M2, global float2 *M3,
    global float2 *M4, global float2 *M5, global float2 *M6, global float2 *M7,
    global float2 *M8, global float2 *M9, global float2 *M10,
    global float2 *M11, global float2 *M12, global float2 *M13,
    global float2 *M14, global float2 *M15, global float2 *M16,
    global float2 *M17, global float2 *M18, global float2 *M19,
    global float *D0, global float *D1, global float *D2, global float *D3,
    global float *D4, global float *D5, global float *D6, global float *D7,
    global float *D8, global float *D9, global float *D10, global float *D11,
    global float *D12, global float *D13, global float *D14, global float *D15,
    global float *D16, global float *D17, global float *D18, global float *D19)
{

    int ii = get_global_id(0); // == get_global_id(0);
    int jj = get_global_id(1); // == get_global_id(1);

    int2 coords = (int2)(ii, jj);

    global float2 *mi = choose_m(&rand_n[jj * width + ii], model_size, M0, M1,
                                 M2, M3, M4, M5, M6, M7, M8, M9, M10, M11, M12,
                                 M13, M14, M15, M16, M17, M18, M19);

    float avr = 1.f;
    uchar color = 0;
    if (index_r[jj * width + ii] >= min_index)
    {
        color = 0;

        if (index_l == model_size)
        {
            const int pos_b = jj * width + ii;
            //
            float ratio = ceil((float)T_upper / T[jj * width + ii]);
            const float I_i = feature[pos_b].x;
            const float I_m = feature[pos_b].y;

            const float B_i = mi[pos_b].x;
            const float B_m = mi[pos_b].y;

            int rand_T = lfsr113_Bits(&rand_n[jj * width + ii]) % T_upper;

            if (rand_T < ratio)
            {
                /* if (IS_BOUNDS(ii * jj, width * height)) */
                {
                    mi[pos_b].x = I_i;
                    mi[pos_b].y = I_m;

                    avr = D0[pos_b] + D1[pos_b] + D2[pos_b] + D3[pos_b] +
                          D4[pos_b] + D5[pos_b] + D6[pos_b] + D7[pos_b] +
                          D8[pos_b] + D9[pos_b] + D10[pos_b] + D11[pos_b] +
                          D12[pos_b] + D13[pos_b] + D14[pos_b] + D15[pos_b] +
                          D16[pos_b] + D17[pos_b] + D18[pos_b] + D19[pos_b];
                    avr /= model_size;
                }
            }
            rand_T = lfsr113_Bits(&rand_n[jj * width + ii]) % T_upper;
            if (rand_T < ratio)
            {
                mi = choose_m(&rand_n[jj * width + ii], model_size, M0, M1, M2,
                              M3, M4, M5, M6, M7, M8, M9, M10, M11, M12, M13,
                              M14, M15, M16, M17, M18, M19);

                const int n_y = -1 + lfsr113_Bits(&rand_n[jj * width + ii]) % 3;
                const int n_x = -1 + lfsr113_Bits(&rand_n[jj * width + ii]) % 3;

                if ((jj + n_y) >= 0 && (jj + n_y) < height && (ii + n_x) >= 0 &&
                    (ii + n_x) < width)
                {
                    const int pos_b = (jj + n_y) * width + ii + n_x;
                    mi[pos_b].x = feature[pos_b].x;
                    mi[pos_b].y = feature[pos_b].y;
                }
            }
        }
    }
    else
    {
        color = 255;
    }
    /* if (IS_BOUNDS(ii * jj, width * height)) */
    {
        mask[jj * width + ii] = color;
        avrg_d[jj * width + ii] = avr;
    }
}

kernel void update_T_R(global uchar *mask, const uint width, const uint height,
                       global float *R, global float *T, global float *avrg_d)
{
    int ii = get_global_id(0); // == get_global_id(0);
    int jj = get_global_id(1); // == get_global_id(1);
    int2 coords = (int2)(ii, jj);

    float R_val = R[jj * width + ii];
    float T_val = T[jj * width + ii];
    const uint pos = jj * width + ii;

    const uchar color = mask[pos];
    const float avr = avrg_d[pos];

    if (R_val > avr * R_scale)
    {
        R_val = R_val * (1.f - R_inc_dec);
    }
    else
    {
        R_val = R_val * (1.f + R_inc_dec);
    }

    if (R_val < R_lower)
        R_val = (float)R_lower;

    if (color == 0)
    {
        T_val += (T_dec / avr);
    }
    else
    {
        T_val -= (T_inc / avr);
    }

    if (T_val < T_lower)
        T_val = T_lower;
    else if (T_val > T_upper)
        T_val = T_upper;

    /* if (IS_BOUNDS(coords.x, width) && IS_BOUNDS(coords.y, height)) */
    {
        R[jj * width + ii] = R_val;
        T[jj * width + ii] = T_val;
    }
}
