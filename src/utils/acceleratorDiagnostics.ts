import {Platform} from 'react-native';
import DeviceInfo from 'react-native-device-info';
import RNFS from '@dr.pogodin/react-native-fs';
import Share from 'react-native-share';
import {
  addNativeLogListener,
  getBackendDevicesInfo,
  toggleNativeLog,
} from 'llama.rn';
import {getChipsetInfo, getCpuInfo, getGpuInfo} from './deviceCapabilities';

const errorText = (error: unknown) =>
  error instanceof Error ? `${error.name}: ${error.message}` : String(error);

/** Collect hardware/backend probes and native llama.cpp logs into a shareable report. */
export async function exportAcceleratorDiagnostics(): Promise<void> {
  const sections: string[] = [];
  const record = async (label: string, probe: () => Promise<unknown>) => {
    try {
      sections.push(`${label}:\n${JSON.stringify(await probe(), null, 2)}`);
    } catch (error) {
      sections.push(`${label} ERROR:\n${errorText(error)}`);
    }
  };

  await record('Device', async () => ({
    brand: await DeviceInfo.getBrand(),
    model: await DeviceInfo.getModel(),
    deviceId: await DeviceInfo.getDeviceId(),
    systemName: DeviceInfo.getSystemName(),
    systemVersion: DeviceInfo.getSystemVersion(),
    apiLevel: Platform.OS === 'android' ? Platform.Version : undefined,
    chipset: await getChipsetInfo(),
    totalMemoryBytes: await DeviceInfo.getTotalMemory(),
    isEmulator: await DeviceInfo.isEmulator(),
  }));
  await record('CPU info', getCpuInfo);
  await record('GPU info', getGpuInfo);
  await record('llama.rn registered backend devices', getBackendDevicesInfo);

  const nativeLogs: string[] = [];
  const subscription = addNativeLogListener((level, text) => {
    nativeLogs.push(`[${new Date().toISOString()}] ${level}: ${text}`);
  });
  try {
    await toggleNativeLog(true);
    await record('Backend devices re-query', getBackendDevicesInfo);
  } finally {
    subscription.remove();
    await toggleNativeLog(false).catch(error => {
      nativeLogs.push(`Could not disable native logging: ${errorText(error)}`);
    });
  }

  sections.push(`Native llama.cpp logs during diagnostic query:\n${nativeLogs.join('\n') || '(no native log lines emitted)'}`);
  sections.push('Configured model loading settings:\nSee PocketPal Settings > Model > Backend; this report intentionally does not include prompts, chat history, model paths, or account data.');

  const filename = `pocketpal-accelerator-diagnostics-${new Date()
    .toISOString()
    .replace(/[:.]/g, '-')}.txt`;
  const path = `${RNFS.CachesDirectoryPath}/${filename}`;
  await RNFS.writeFile(
    path,
    `PocketPal accelerator diagnostics\nGenerated: ${new Date().toISOString()}\n\n${sections.join('\n\n')}`,
    'utf8',
  );
  await Share.open({
    url: `file://${path}`,
    title: 'Share accelerator diagnostics',
    type: 'text/plain',
    failOnCancel: false,
  });
}
