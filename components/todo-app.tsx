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
  const isInitialSave = useRef(true)

  useEffect(() => {
    // localStorage는 서버에 없는 외부 소스라 마운트 후에만 읽을 수 있다.
    // eslint-disable-next-line react-hooks/set-state-in-effect
    setTodos(loadTodos())
  }, [])

  useEffect(() => {
    // 이 이펙트의 첫 실행은 초기 state([])를 저장해 방금 불러온 데이터를
    // 덮어쓰므로 건너뛴다. 이후 실행부터는 실제 변경 사항을 저장한다.
    if (isInitialSave.current) {
      isInitialSave.current = false
      return
    }
    saveTodos(todos)
  }, [todos])

  function handleAdd() {
    const trimmed = text.trim()
    if (!trimmed) return
    setTodos((prev) => [{ id: createId(), text: trimmed, completed: false }, ...prev])
    setText("")
  }

  function handleToggle(id: string) {
    setTodos((prev) =>
      prev.map((todo) => (todo.id === id ? { ...todo, completed: !todo.completed } : todo))
    )
  }

  function handleDelete(id: string) {
    setTodos((prev) => prev.filter((todo) => todo.id !== id))
  }

  function handleCommitEdit(id: string, nextText: string) {
    const trimmed = nextText.trim()
    setTodos((prev) =>
      prev.map((todo) => (todo.id === id ? { ...todo, text: trimmed || todo.text } : todo))
    )
    setEditingId(null)
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
              onStartEdit={() => setEditingId(todo.id)}
              onCommitEdit={(nextText) => handleCommitEdit(todo.id, nextText)}
              onCancelEdit={() => setEditingId(null)}
            />
          ))}
        </ul>
      )}
    </div>
  )
}
