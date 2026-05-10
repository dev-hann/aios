import { BrowserRouter, Routes, Route } from 'react-router-dom';
import { ChatScreen } from './components/ChatScreen';
import { SettingsScreen } from './components/SettingsScreen';
import { ProviderSettingsScreen } from './components/ProviderSettingsScreen';
import { InferenceSettingsScreen } from './components/InferenceSettingsScreen';
import { PermissionManagementScreen } from './components/PermissionManagementScreen';

function App() {
  return (
    <BrowserRouter>
      <Routes>
        <Route path="/" element={<ChatScreen />} />
        <Route path="/settings" element={<SettingsScreen />} />
        <Route path="/settings/provider" element={<ProviderSettingsScreen />} />
        <Route path="/settings/inference" element={<InferenceSettingsScreen />} />
        <Route path="/settings/permissions" element={<PermissionManagementScreen />} />
      </Routes>
    </BrowserRouter>
  );
}

export default App;
