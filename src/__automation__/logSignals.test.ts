import {
  deriveEffectiveBackend,
  deriveLogSignals,
  requestSatisfiedBy,
} from './logSignals';

describe('Vulkan backend diagnostics', () => {
  it('counts Vulkan as GPU use only when model weights landed on it', () => {
    const signals = deriveLogSignals([
      'ggml_vulkan: Found Vulkan device: Xclipse 960',
      'load_tensors: Vulkan0 model buffer size = 128.00 MiB',
      'load_tensors: CPU model buffer size = 32.00 MiB',
      'load_tensors: offloaded 24/32 layers to GPU',
    ]);

    expect(deriveEffectiveBackend(signals)).toBe('cpu+vulkan-partial');
    expect(requestSatisfiedBy('gpu', deriveEffectiveBackend(signals))).toBe(
      true,
    );
  });

  it('does not count a Vulkan registry message with CPU-only weights as GPU use', () => {
    const signals = deriveLogSignals([
      'ggml_vulkan: Found Vulkan device: Xclipse 960',
      'load_tensors: CPU model buffer size = 128.00 MiB',
    ]);

    expect(deriveEffectiveBackend(signals)).toBe('cpu');
    expect(requestSatisfiedBy('gpu', deriveEffectiveBackend(signals))).toBe(
      false,
    );
  });

  it('keeps an init that failed before weight placement unknown', () => {
    expect(
      deriveEffectiveBackend(
        deriveLogSignals(['ggml_vulkan: Found Vulkan device: Xclipse 960']),
      ),
    ).toBe('unknown');
  });
});
