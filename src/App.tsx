/**
 * @license
 * SPDX-License-Identifier: Apache-2.0
 */

import { VegaProvider } from './context/VegaContext.tsx';
import { AppShell } from './components/AppShell.tsx';

export default function App() {
  return (
    <VegaProvider>
      <AppShell />
    </VegaProvider>
  );
}
