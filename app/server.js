// server.js: Express API with in-memory task store + /health endpoint used by CI health checks.
const express = require("express");
const path = require("path");
const app = express();

app.use(express.json());
app.use(express.static(path.join(__dirname, "public")));

let tasks = [
  { id: 1, title: "Set up CI/CD", done: true },
  { id: 2, title: "Deploy to Beta", done: false },
];
let nextId = 3;

// Health endpoint — returns env name so CI can verify correct instance
app.get("/health", (req, res) => {
  res.json({
    status: "ok",
    env: process.env.APP_ENV || "unknown",
    version: process.env.APP_VERSION || "dev",
    uptime: process.uptime(),
  });
});

app.get("/api/tasks", (req, res) => res.json(tasks));

app.post("/api/tasks", (req, res) => {
  const { title } = req.body;
  if (!title || !title.trim()) return res.status(400).json({ error: "title required" });
  const task = { id: nextId++, title: title.trim(), done: false };
  tasks.push(task);
  res.status(201).json(task);
});

app.put("/api/tasks/:id", (req, res) => {
  const id = Number(req.params.id);
  const task = tasks.find((t) => t.id === id);
  if (!task) return res.status(404).json({ error: "not found" });
  if (typeof req.body.done === "boolean") task.done = req.body.done;
  if (typeof req.body.title === "string") task.title = req.body.title;
  res.json(task);
});

app.delete("/api/tasks/:id", (req, res) => {
  const id = Number(req.params.id);
  const before = tasks.length;
  tasks = tasks.filter((t) => t.id !== id);
  if (tasks.length === before) return res.status(404).json({ error: "not found" });
  res.status(204).end();
});

const PORT = process.env.PORT || 3000;
app.listen(PORT, () => console.log(`Task app on ${PORT} env=${process.env.APP_ENV}`));
