import { TodoApp } from "@/components/todo-app";

export default function Home() {
  return (
    <div className="flex flex-1 flex-col bg-background">
      <TodoApp />
    </div>
  );
}
