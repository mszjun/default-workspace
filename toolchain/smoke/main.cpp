// 工具链冒烟测试：验证 C++20、线程、原子、chrono 和 64 字节对齐都能编能跑。
#include <atomic>
#include <chrono>
#include <cstdint>
#include <cstdio>
#include <thread>

#if defined(_MSC_VER)
#define COMPILER_STR2(x) #x
#define COMPILER_STR(x) COMPILER_STR2(x)
#define COMPILER "MSVC " COMPILER_STR(_MSC_FULL_VER)
#elif defined(__clang__)
#define COMPILER "Clang " __clang_version__
#elif defined(__GNUC__)
#define COMPILER "GCC " __VERSION__
#else
#define COMPILER "unknown"
#endif

struct alignas(64) Probe {
    std::int64_t a;
    std::int64_t b;
    char padding[48];
};

int main() {
    std::atomic<std::uint64_t> counter{0};
    std::thread t([&] {
        for (int i = 0; i < 100000; ++i) counter.fetch_add(1, std::memory_order_relaxed);
    });
    t.join();

    auto start = std::chrono::steady_clock::now();
    auto ns = std::chrono::duration_cast<std::chrono::nanoseconds>(
                  std::chrono::steady_clock::now() - start)
                  .count();

    std::printf("compiler=%s\n", COMPILER);
    std::printf("cplusplus=%ld ptr=%zu cacheline=%zu\n", static_cast<long>(__cplusplus),
                sizeof(void*), alignof(Probe));
    std::printf("counter=%llu chrono_ns=%lld\n",
                static_cast<unsigned long long>(counter.load()), static_cast<long long>(ns));

    const bool ok = counter.load() == 100000 && sizeof(void*) == 8 && alignof(Probe) == 64 &&
                    __cplusplus >= 202002L;
    std::printf("SMOKE=%s\n", ok ? "PASS" : "FAIL");
    return ok ? 0 : 1;
}
