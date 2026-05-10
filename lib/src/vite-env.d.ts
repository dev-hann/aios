/// <reference types="vite/client" />

interface ImportMetaEnv {
  readonly VITE_API_KEY: string;
  readonly VITE_PROVIDER_TYPE: string;
  readonly VITE_MODEL: string;
}

interface ImportMeta {
  readonly env: ImportMetaEnv;
}
