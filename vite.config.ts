import { GoogleGenAI } from "@google/genai";
import react from "@vitejs/plugin-react";
import { defineConfig, loadEnv, type Plugin } from "vite";

// Mints short-lived Live API tokens so the real API key never reaches the browser.
function ephemeralTokenPlugin(apiKey: string | undefined): Plugin {
  return {
    name: "ephemeral-token",
    configureServer(server) {
      server.middlewares.use("/api/token", async (_req, res) => {
        res.setHeader("Content-Type", "application/json");
        if (!apiKey) {
          res.statusCode = 500;
          res.end(JSON.stringify({ error: "GEMINI_API_KEY is not set in .env.local" }));
          return;
        }
        try {
          const ai = new GoogleGenAI({ apiKey, httpOptions: { apiVersion: "v1alpha" } });
          const token = await ai.authTokens.create({
            config: {
              // One session per translation direction.
              uses: 2,
              expireTime: new Date(Date.now() + 30 * 60_000).toISOString(),
              newSessionExpireTime: new Date(Date.now() + 60_000).toISOString(),
            },
          });
          res.end(JSON.stringify({ token: token.name }));
        } catch (error) {
          res.statusCode = 500;
          res.end(JSON.stringify({ error: String(error) }));
        }
      });
    },
  };
}

export default defineConfig(({ mode }) => {
  const env = loadEnv(mode, process.cwd(), "");
  return { plugins: [react(), ephemeralTokenPlugin(env.GEMINI_API_KEY)] };
});
