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
  // 편집 대상을 다른 항목으로 바꾸거나 편집을 끝내면, 방금 언마운트된
  // 입력 필드에서 지연된 blur가 뒤늦게 도착해 이미 버려진 초안을 다시
  // 커밋하려 할 수 있다. 렌더와 무관하게 항상 최신값을 가리키는 ref로
  // 그 지연된 커밋을 걸러낸다.
  const editingIdRef = useRef<string | null>(null)

  function setEditing(id: string | null) {
    editingIdRef.current = id
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

  function handleCommitEdit(id: string, nextText: string) {
    // 이 항목이 더 이상 활성 편집 대상이 아니면, 언마운트로 인한
    // 지연된 blur 호출이므로 무시한다 (버려진 초안을 저장하지 않는다).
    if (editingIdRef.current !== id) return

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
          if (event.key === "Enter") handleAdd()
        }}
        placeholder="할 일을 입력하고 Enter를 누르세요"
        aria-label="새 할 일"
      />
      {todos.length === 0 ? (
        <p className="text-sm text-muted-foreground">할 일이 없습니다.</p>
      ) : (
        <ul className="flex flex-col gap-2">
          {todos.map((todo) => (
            <TodoItem
              key={todo.id}
              todo={todo}
              isEditing={editingId === todo.id}
              onToggle={() => handleToggle(todo.id)}
              onDelete={() => handleDelete(todo.id)}
              onStartEdit={() => setEditing(todo.id)}
              onCommitEdit={(nextText) => handleCommitEdit(todo.id, nextText)}
              onCancelEdit={() => setEditing(null)}
            />
          ))}
        </ul>
      )}
    </div>
  )
}
