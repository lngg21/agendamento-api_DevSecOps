import "reflect-metadata";
import express from "express";
import cors from "cors";
import routes from "./routes";
import { errorHandler } from "./middlewares/errorHandler";
import { metricsMiddleware } from "./middlewares/metricsMiddleware";
import { register } from "./config/metrics";
import { AppDataSource } from "./config/database";

const app = express();

// Middlewares globais
app.use(cors());
app.use(express.json());
app.use(metricsMiddleware);

// Rota de health check (liveness + readiness combinados)
app.get("/api/health", (_req, res) => {
  const dbConnected = AppDataSource.isInitialized;

  if (!dbConnected) {
    return res.status(503).json({
      status: "error",
      message: "Banco de dados indisponível",
      timestamp: new Date().toISOString(),
    });
  }

  res.status(200).json({
    status: "success",
    message: "API de Agendamento de Consultas está funcionando!",
    timestamp: new Date().toISOString(),
  });
});

// Rotas da API
app.use("/api", routes);

// Endpoint de métricas para o Prometheus
app.get("/metrics", async (_req, res) => {
  res.set("Content-Type", register.contentType);
  res.end(await register.metrics());
});

// Middleware de tratamento de erros (deve ser o último)
app.use(errorHandler);

export default app;