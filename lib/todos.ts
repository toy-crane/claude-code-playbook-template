export type Todo = {
  id: string;
  text: string;
  completed: boolean;
};

const STORAGE_KEY = "todos";

function isTodo(value: unknown): value is Todo {
  if (typeof value !== "object" || value === null) return false;
  const candidate = value as Record<string, unknown>;
  return (
    typeof candidate.id === "string" &&
    typeof candidate.text === "string" &&
    typeof candidate.completed === "boolean"
  );
}

export function loadTodos(): Todo[] {
  if (typeof window === "undefined") return [];

  try {
    const raw = window.localStorage.getItem(STORAGE_KEY);
    if (!raw) return [];
    const parsed: unknown = JSON.parse(raw);
    if (!Array.isArray(parsed)) return [];
    return parsed.filter(isTodo);
  } catch {
    return [];
  }
}

export function saveTodos(todos: Todo[]): void {
  if (typeof window === "undefined") return;
  try {
    window.localStorage.setItem(STORAGE_KEY, JSON.stringify(todos));
  } catch {
    // 저장 공간이 없거나(private mode 등) 접근이 차단된 경우 조용히 무시한다.
  }
}
