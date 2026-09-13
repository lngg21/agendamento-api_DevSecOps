import client from "prom-client";

// Coleta métricas padrão do processo Node (CPU, memória, event loop, etc.)
const register = new client.Registry();
client.collectDefaultMetrics({ register });

// Contador de requisições HTTP por método, rota e status
export const httpRequestCounter = new client.Counter({
  name: "http_requests_total",
  help: "Total de requisições HTTP recebidas",
  labelNames: ["method", "route", "status_code"],
  registers: [register],
});

// Histograma de latência (necessário para p95/p99 mencionados na doc)
export const httpRequestDuration = new client.Histogram({
  name: "http_request_duration_seconds",
  help: "Duração das requisições HTTP em segundos",
  labelNames: ["method", "route", "status_code"],
  buckets: [0.01, 0.05, 0.1, 0.3, 0.5, 1, 2, 5],
  registers: [register],
});

export { register };