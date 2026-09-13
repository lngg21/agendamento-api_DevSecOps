import { Request, Response, NextFunction } from "express";
import { httpRequestCounter, httpRequestDuration } from "../config/metrics";

export function metricsMiddleware(req: Request, res: Response, next: NextFunction) {
  const end = httpRequestDuration.startTimer();

  res.on("finish", () => {
    const route = req.route?.path || req.path;

    httpRequestCounter.inc({
      method: req.method,
      route,
      status_code: res.statusCode,
    });

    end({
      method: req.method,
      route,
      status_code: res.statusCode,
    });
  });

  next();
}