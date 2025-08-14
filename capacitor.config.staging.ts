import { CapacitorConfig } from '@capacitor/cli';
const config: CapacitorConfig = {
  appId: 'it.kim.station',
  appName: 'Kim Station',
  webDir: 'www',
  server: {
    url: 'https://arm.kimweb.agency',
    cleartext: false,
    androidScheme: 'https',
    // @ts-ignore: appendUserAgent may not be typed in this Capacitor CLI version
    appendUserAgent: ' KimStationApp'
  }
};
export default config;
