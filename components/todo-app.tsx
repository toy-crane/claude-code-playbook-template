"use client"

import { useEffect, useRef, useState } from "react"

import { TodoItem } from "@/components/todo-item"
import { Input } from "@/components/ui/input"
import { loadTodos, saveTodos, type Todo } from "@/lib/todos"

function createId() {
  return typeof crypto !== "undefined" && "randomUUID" in crypto
    ? crypto.randomUUID()
    : Math.random().toString(36).slice(2)
}

export function TodoApp() {
  const [todos, setTodos] = useState<Todo[]>([])
  const [text, setText] = useState("")
  const [editingId, setEditingId] = useState<string | null>(null)
  // 편집을 시작/종료할 때마다 늘어나는 세션 번호. 언마운트된 입력
  // 필드에서 지연된 blur가 뒤늦게 도착했을 때, 그 사이 같은 항목을
  // 다시 편집하기 시작했더라도(id는 같아도 세션은 다름) 지연된
  // 커밋을 정확히 구분해 걸러낸다.
  const editSessionRef = useRef(0)

  function setEditing(id: string | null) {
    editSessionRef.current += 1
    setEditingId(id)
  }

  useEffect(() => {
    // localStorage는 서버에 없는 외부 소스라 마운트 후에만 읽을 수 있다.
    // eslint-disable-next-line react-hooks/set-state-in-effect
    setTodos(loadTodos())
  }, [])

  function commit(next: Todo[]) {
    setTodos(next)
    saveTodos(next)
  }

  function handleAdd() {
    const trimmed = text.trim()
    if (!trimmed) return
    commit([{ id: createId(), text: trimmed, completed: false }, ...todos])
    setText("")
  }

  function handleToggle(id: string) {
    commit(todos.map((todo) => (todo.id === id ? { ...todo, completed: !todo.completed } : todo)))
  }

  function handleDelete(id: string) {
    commit(todos.filter((todo) => todo.id !== id))
  }

  function handleCommitEdit(id: string, nextText: string, session: number) {
    // 이 호출을 만든 편집 세션이 더 이상 최신이 아니면, 언마운트로 인한
    // 지연된 blur 호출이므로 무시한다 (버려진 초안을 저장하지 않는다).
    if (session !== editSessionRef.current) return

    const trimmed = nextText.trim()
    commit(
      todos.map((todo) => (todo.id === id ? { ...todo, text: trimmed || todo.text } : todo))
    )
    setEditing(null)
  }

  return (
    <div className="mx-auto flex w-full max-w-md flex-col gap-4 px-4 py-16">
      <h1 className="text-2xl font-semibold text-foreground">Todo</h1>
      <Input
        value={text}
        onValueChange={setText}
        onKeyDown={(event) => {
          if (event.key === "Enter" && !event.nativeEvent.isComposing) handleAdd()
        }}
        placeholder="할 일을 입력하고 Enter를 누르세요"
        aria-label="새 할 일"
      />
      {todos.length === 0 ? (
        <p className="text-sm text-muted-foreground">할 일이 없습니다.</p>
      ) : (
        <ul className="flex flex-col gap-2">
          {todos.map((todo) => {
            // 클로저 안에서 editSessionRef.current를 직접 참조하면 호출 시점에
            // (뒤늦게 도착한 blur라도) 항상 "최신" 값을 읽어버려 가드가
            // 무력화된다. 이 렌더 시점의 값을 별도 상수로 스냅샷해 닫아야
            // 나중에 handleCommitEdit이 최신 값과 비교할 수 있다.
            const session = editSessionRef.current
            return (
              <TodoItem
                key={todo.id}
                todo={todo}
                isEditing={editingId === todo.id}
                onToggle={() => handleToggle(todo.id)}
                onDelete={() => handleDelete(todo.id)}
                onStartEdit={() => setEditing(todo.id)}
                onCommitEdit={(nextText) => handleCommitEdit(todo.id, nextText, session)}
                onCancelEdit={() => setEditing(null)}
              />
            )
          })}
        </ul>
      )}
    </div>
  )
}
