export type Todo = {
  id: string;
  text: string;
  done: boolean;
};

const STORAGE_KEY = "todo-app.todos";

let sequence = 0;

/** 브라우저 안에서 항목을 구분할 수 있을 만큼만 고유한 식별자를 만든다. */
export function createTodo(text: string): Todo {
  sequence += 1;
  return {
    id: `${Date.now().toString(36)}-${sequence.toString(36)}`,
    text,
    done: false,
  };
}

/**
 * 저장된 목록을 읽는다.
 * 저장소를 쓸 수 없거나 값이 손상됐으면 빈 목록으로 시작한다.
 */
export function readTodos(): Todo[] {
  try {
    const raw = localStorage.getItem(STORAGE_KEY);
    if (raw === null) return [];

    const parsed: unknown = JSON.parse(raw);
    if (!Array.isArray(parsed)) return [];

    return parsed.filter(isTodo);
  } catch {
    return [];
  }
}

/**
 * 목록을 저장한다.
 * 사생활 보호 모드나 용량 초과로 저장이 막혀도 화면 조작은 계속 되어야 하므로
 * 실패를 조용히 넘긴다. 별도의 오류 안내를 두지 않는 것은 스펙의 가정이다.
 */
export function writeTodos(todos: Todo[]): void {
  try {
    localStorage.setItem(STORAGE_KEY, JSON.stringify(todos));
  } catch {
    return;
  }
}

function isTodo(value: unknown): value is Todo {
  if (typeof value !== "object" || value === null) return false;

  const candidate = value as Record<string, unknown>;
  return (
    typeof candidate.id === "string" &&
    typeof candidate.text === "string" &&
    typeof candidate.done === "boolean"
  );
}
