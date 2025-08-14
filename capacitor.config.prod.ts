import { CapacitorConfig } from '@capacitor/cli';
const config: CapacitorConfig = {
  appId: 'it.kim.station',
  appName: 'Kim Station',
  webDir: 'www',
  server: {
    url: 'https://station.kimweb.agency',
    cleartext: false,
    androidScheme: 'https'
  }
};
export default config;
