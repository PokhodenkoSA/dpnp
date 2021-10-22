# cython: language_level=3
# -*- coding: utf-8 -*-
# *****************************************************************************
# Copyright (c) 2016-2020, Intel Corporation
# All rights reserved.
#
# Redistribution and use in source and binary forms, with or without
# modification, are permitted provided that the following conditions are met:
# - Redistributions of source code must retain the above copyright notice,
#   this list of conditions and the following disclaimer.
# - Redistributions in binary form must reproduce the above copyright notice,
#   this list of conditions and the following disclaimer in the documentation
#   and/or other materials provided with the distribution.
#
# THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS"
# AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE
# IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE
# ARE DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT HOLDER OR CONTRIBUTORS BE
# LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR
# CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF
# SUBSTITUTE GOODS OR SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS
# INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN
# CONTRACT, STRICT LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE)
# ARISING IN ANY WAY OUT OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED OF
# THE POSSIBILITY OF SUCH DAMAGE.
# *****************************************************************************

"""Module Backend (FFT part)

This module contains interface functions between C backend layer
and the rest of the library

"""


from dpnp.dpnp_algo cimport *
cimport dpnp.dpnp_utils as utils


__all__ = [
    "dpnp_fft",
    "dpnp_rfft"
]


ctypedef void(*fptr_dpnp_fft_t)(void *, void * , size_t, size_t, long * , long * , size_t, long * , long * , size_t, size_t, long, double, long, size_t)


cpdef utils.dpnp_descriptor dpnp_fft(utils.dpnp_descriptor input,
                                     size_t input_boundarie,
                                     size_t output_boundarie,
                                     long axis,
                                     size_t inverse):

    cdef shape_type_c input_shape = input.shape
    cdef shape_type_c output_shape = input_shape
    cdef shape_type_c input_strides
    cdef shape_type_c result_strides
    cdef double fsc = 1.0
    cdef long all_harmonics = 1

    cdef size_t input_itemsize = input.dtype.itemsize
    cdef size_t output_itemsize

    input_strides = utils.strides_to_vector(input.strides, input.shape)

    cdef long axis_norm = utils.normalize_axis((axis,), input_shape.size())[0]
    output_shape[axis_norm] = output_boundarie

    # convert string type names (dtype) to C enum DPNPFuncType
    cdef DPNPFuncType param1_type = dpnp_dtype_to_DPNPFuncType(input.dtype)

    # get the FPTR data structure
    cdef DPNPFuncData kernel_data = get_dpnp_function_ptr(DPNP_FN_FFT_FFT, param1_type, param1_type)

    # ceate result array with type given by FPTR data
    cdef utils.dpnp_descriptor result = utils.create_output_descriptor(output_shape, kernel_data.return_type, None)

    output_itemsize = result.dtype.itemsize

    result_strides = utils.strides_to_vector(result.strides, result.shape)

    cdef fptr_dpnp_fft_t func = <fptr_dpnp_fft_t > kernel_data.ptr

    # call FPTR function
    func(input.get_data(), result.get_data(), input.size, result.size, input_shape.data(), output_shape.data(), input_shape.size(
    ), input_strides.data(), result_strides.data(), input_itemsize, output_itemsize, axis, fsc, all_harmonics, inverse)

    return result


cpdef utils.dpnp_descriptor dpnp_rfft(utils.dpnp_descriptor input,
                                      size_t input_boundarie,
                                      size_t output_boundarie,
                                      long axis,
                                      size_t inverse):

    cdef shape_type_c input_shape = input.shape
    cdef shape_type_c output_shape = input_shape
    cdef shape_type_c input_strides
    cdef shape_type_c result_strides
    cdef double fsc = 1.0
    cdef long all_harmonics = 1

    cdef size_t input_itemsize = input.dtype.itemsize
    cdef size_t output_itemsize

    input_strides = utils.strides_to_vector(input.strides, input.shape)

    cdef long axis_norm = utils.normalize_axis((axis,), input_shape.size())[0]
    output_shape[axis_norm] = output_boundarie

    # convert string type names (dtype) to C enum DPNPFuncType
    cdef DPNPFuncType param1_type = dpnp_dtype_to_DPNPFuncType(input.dtype)

    # get the FPTR data structure
    cdef DPNPFuncData kernel_data = get_dpnp_function_ptr(DPNP_FN_FFT_RFFT, param1_type, param1_type)

    # ceate result array with type given by FPTR data
    cdef utils.dpnp_descriptor result = utils.create_output_descriptor(output_shape, kernel_data.return_type, None)

    output_itemsize = result.dtype.itemsize

    result_strides = utils.strides_to_vector(result.strides, result.shape)

    cdef fptr_dpnp_fft_t func = <fptr_dpnp_fft_t > kernel_data.ptr

    # call FPTR function
    func(input.get_data(), result.get_data(), input.size, result.size, input_shape.data(), output_shape.data(), input_shape.size(
    ), input_strides.data(), result_strides.data(), input_itemsize, output_itemsize, axis, fsc, all_harmonics, inverse)

    return result
