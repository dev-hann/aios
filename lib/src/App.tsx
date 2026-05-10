import { BrowserRouter, Routes, Route } from 'react-router-dom';
import { ChatScreen } from './components/ChatScreen';
import { SettingsScreen } from './components/SettingsScreen';
import { ProviderSettingsScreen } from './components/ProviderSettingsScreen';

function App() {
  return (
    <BrowserRouter>
      <Routes>
        <Route path="/" element={<ChatScreen />} />
        <Route path="/settings" element={<SettingsScreen />} />
        <Route path="/settings/provider" element={<ProviderSettingsScreen />} />
      </Routes>
    </BrowserRouter>
  );
}

export default App;
