import {AppRegistry, LogBox} from 'react-native';
import Nina from './src/Nina';

if (__DEV__) {
  LogBox.ignoreLogs([/^Open debugger to view warnings\.$/]);
}

AppRegistry.registerComponent('Nina', () => Nina);
