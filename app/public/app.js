// app.js: Frontend logic — fetches /api/tasks, renders with colors, and shows env badge from /health.
const list = document.getElementById("task-list");
const form = document.getElementById("task-form");
const input = document.getElementById("task-input");

async function loadHealth() {
  try {
    const r = await fetch("/health");
    const h = await r.json();
    document.getElementById("env-badge").textContent = `env: ${h.env}`;
    document.getElementById("version-badge").textContent = `v: ${h.version}`;
  } catch { /* ignore */ }
}

async function loadTasks() {
  const r = await fetch("/api/tasks");
  const tasks = await r.json();
  list.innerHTML = "";
  tasks.forEach(renderTask);
}

function renderTask(task) {
  const li = document.createElement("li");
  if (task.done) li.classList.add("done");

  const cb = document.createElement("input");
  cb.type = "checkbox";
  cb.checked = task.done;
  cb.onchange = () => toggle(task.id, cb.checked);

  const span = document.createElement("span");
  span.className = "title";
  span.textContent = task.title;

  const actions = document.createElement("div");
  actions.className = "actions";

  const del = document.createElement("button");
  del.textContent = "Delete";
  del.className = "delete";
  del.onclick = () => remove(task.id);

  actions.appendChild(del);
  li.append(cb, span, actions);
  list.appendChild(li);
}

async function addTask(title) {
  await fetch("/api/tasks", {
    method: "POST",
    headers: { "Content-Type": "application/json" },
    body: JSON.stringify({ title }),
  });
  loadTasks();
}

async function toggle(id, done) {
  await fetch(`/api/tasks/${id}`, {
    method: "PUT",
    headers: { "Content-Type": "application/json" },
    body: JSON.stringify({ done }),
  });
  loadTasks();
}

async function remove(id) {
  await fetch(`/api/tasks/${id}`, { method: "DELETE" });
  loadTasks();
}

form.onsubmit = (e) => {
  e.preventDefault();
  const v = input.value.trim();
  if (v) { addTask(v); input.value = ""; }
};

loadHealth();
loadTasks();
