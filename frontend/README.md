# Frontend

## Running the dev server

Requires **Node 20.19+** (Vite 7's dev server uses `crypto.hash`; Node 18 will
crash). The version is pinned in `.nvmrc`, so:

```bash
cd frontend
nvm use          # reads .nvmrc -> Node 22, no version to remember
npm install      # first time only
npm run dev      # http://localhost:5173  (use localhost, not 127.0.0.1)
```

The dev server proxies `/api` and `/cable` to Rails on :3000, so start the
backend (`bin/rails server -p 3000`) too.

---

# React + Vite

This template provides a minimal setup to get React working in Vite with HMR and some Oxlint rules.

Currently, two official plugins are available:

- [@vitejs/plugin-react](https://github.com/vitejs/vite-plugin-react/blob/main/packages/plugin-react) uses [Oxc](https://oxc.rs)
- [@vitejs/plugin-react-swc](https://github.com/vitejs/vite-plugin-react/blob/main/packages/plugin-react-swc) uses [SWC](https://swc.rs/)

## React Compiler

The React Compiler is not enabled on this template because of its impact on dev & build performances. To add it, see [this documentation](https://react.dev/learn/react-compiler/installation).

## Expanding the Oxlint configuration

If you are developing a production application, we recommend using TypeScript with type-aware lint rules enabled. Check out the [TS template](https://github.com/vitejs/vite/tree/main/packages/create-vite/template-react-ts) for information on how to integrate TypeScript and Oxlint's TypeScript related rules in your project.
