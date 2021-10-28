/*
 * dpcpp -g -fPIC -fsycl dpnp/backend/examples/example11.cpp  -o example11 -lmkl_sycl -lmkl_intel_ilp64 -lmkl_tbb_thread -lmkl_core
 * dpcpp -g -fPIC   -W -Wextra -Wshadow -Wall -Wstrict-prototypes -Wformat -Wformat-security -fsycl -fsycl-device-code-split=per_kernel -O0 -fno-delete-null-pointer-checks -fstack-protector-strong -fno-strict-overflow -std=gnu++17 dpnp/backend/examples/example11.cpp -Idpnp -Idpnp/backend/include -Ldpnp -Wl,-rpath='$ORIGIN'/dpnp -ldpnp_backend_c -o example11 -lmkl_sycl -lmkl_intel_ilp64 -lmkl_core
 */
#include <iostream>
#include <time.h>

#include <dpnp_iface.hpp>
#include <dpnp_iface_fptr.hpp>

#include <CL/sycl.hpp>
#include <oneapi/mkl.hpp>

namespace mkl_dft = oneapi::mkl::dft;
namespace mkl_rng = oneapi::mkl::rng;
namespace mkl_vm = oneapi::mkl::vm;

template <typename T>
void print_dpnp_array(T* arr, size_t size)
{
    std::cout << std::endl;
    for (size_t i = 0; i < size; ++i)
    {
        std::cout << arr[i] << ", ";
    }
    std::cout << std::endl;
}

template <typename T>
void init(T* x, size_t size)
{
    for (size_t i = 0; i < size; ++i)
    {
        x[i] = static_cast<T>(i);
    }
}

// For 1dim array
template <typename _DataType>
void shuffle_c(
    void* result, const size_t itemsize, const size_t ndim, const size_t high_dim_size, const size_t size, cl::sycl::queue& queue, size_t seed)
{
    if (!result)
    {
        return;
    }

    if (!size || !ndim || !(high_dim_size > 1))
    {
        return;
    }

    // cl::sycl::queue queue{cl::sycl::gpu_selector()};

    mkl_rng::mt19937 rng_engine = mkl_rng::mt19937(queue, seed);

    // DPNPC_ptr_adapter<char> result1_ptr(result, size * itemsize, true, true);
    // char* result1 = result1_ptr.get_ptr();
    char* result1 = reinterpret_cast<char*>(result);

    size_t uvec_size = high_dim_size - 1;
    // double* array_1 = reinterpret_cast<double*>(malloc_shared(result_size * sizeof(double), queue));
    // double* Uvec = reinterpret_cast<double*>(dpnp_memory_alloc_c(uvec_size * sizeof(double)));

    double* Uvec = reinterpret_cast<double*>(malloc_shared(uvec_size * sizeof(double), queue));

    mkl_rng::uniform<double> uniform_distribution(0.0, 1.0);

    auto uniform_event = mkl_rng::generate(uniform_distribution, rng_engine, uvec_size, Uvec);
    uniform_event.wait();
    // just for debug
    // print_dpnp_array(Uvec, uvec_size);


    // Fast, statically typed path: shuffle the underlying buffer.
    // Only for non-empty, 1d objects of class ndarray (subclasses such
    // as MaskedArrays may not support this approach).
    char* buf = reinterpret_cast<char*>(malloc_shared(sizeof(char), queue));
    for (size_t i = uvec_size; i > 0; i--)
    {
        size_t j = (size_t)(floor((i + 1) * Uvec[i - 1]));
        if (i != j)
        {
            auto memcpy1 =
                queue.submit([&](cl::sycl::handler& h) { h.memcpy(buf, result1 + j * itemsize, itemsize); });
            auto memcpy2 = queue.submit([&](cl::sycl::handler& h) {
                h.depends_on({memcpy1});
                h.memcpy(result1 + j * itemsize, result1 + i * itemsize, itemsize);
            });
            auto memcpy3 = queue.submit([&](cl::sycl::handler& h) {
                h.depends_on({memcpy2});
                h.memcpy(result1 + i * itemsize, buf, itemsize);
            });
            memcpy3.wait();
        }
    }
    free(buf, queue);
    free(Uvec, queue);
    return;
}

int main(int, char**)
{
    cl::sycl::queue queue{cl::sycl::gpu_selector()};
    const size_t itemsize = sizeof(double);
    const size_t ndim = 1;
    const size_t high_dim_size = 100;
    const size_t size = 100;
    const size_t seed = 1234;

    // reproducer for shuffling array (as is in dpnp_rng_shuffle_c)
    // using mathlib interface
    std::cout << "\nREPRODUCE: logic as is in DPNPC dpnp_rng_shuffle_c:";
    double* array_1 = reinterpret_cast<double*>(malloc_shared(size * sizeof(double), queue));
    std::cout << "\nINPUT array 1:";
    init<double>(array_1, size);
    print_dpnp_array(array_1, size);
    shuffle_c<double>(array_1, itemsize, ndim, high_dim_size, size, queue, seed);
    std::cout << "\nSHUFFLE INPUT array:";
    print_dpnp_array(array_1, size);
    free(array_1, queue);

    std::cout << "\n///////////////////////////////////////////////\n";

    // DPNPC dpnp_rng_shuffle_c
    // DPNPC interface
    std::cout << "\nREPRODUCE: DPNPC dpnp_rng_shuffle_c:";
    double* array_2 = reinterpret_cast<double*>(dpnp_memory_alloc_c(size * sizeof(double)));
    // init array
    init<double>(array_2, size);
    // print before shuffle
    std::cout << "\nINPUT array 2:";
    print_dpnp_array(array_2, size);

    dpnp_rng_srand_c(seed);

    dpnp_rng_shuffle_c<double>(array_2, itemsize, ndim, high_dim_size, size);

    // print shuffle result
    std::cout << "\nSHUFFLE INPUT array 2:";
    print_dpnp_array(array_2, size);

    dpnp_memory_free_c(array_2);
}
