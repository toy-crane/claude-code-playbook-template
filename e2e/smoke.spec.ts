import { expect, test } from "@playwright/test";

test("홈 화면이 열리고 Todo 입력창이 보인다", async ({ page }) => {
  await page.goto("/");

  await expect(page).toHaveTitle("Todo");
  await expect(page.getByRole("textbox", { name: "새 할 일" })).toBeVisible();
});

test("Todo를 추가하고 새로고침해도 목록과 완료 상태가 유지된다", async ({ page }) => {
  await page.goto("/");

  const input = page.getByRole("textbox", { name: "새 할 일" });
  await input.fill("우유 사기");
  await input.press("Enter");
  await input.fill("청소하기");
  await input.press("Enter");

  await page.getByRole("checkbox", { name: "청소하기 완료" }).click();

  await page.reload();

  const items = page.getByRole("listitem");
  await expect(items).toHaveCount(2);
  await expect(items.filter({ hasText: "우유 사기" })).toBeVisible();
  await expect(items.filter({ hasText: "청소하기" })).toBeVisible();
  await expect(page.getByRole("checkbox", { name: "청소하기 완료" })).toBeChecked();
  await expect(page.getByRole("checkbox", { name: "우유 사기 완료" })).not.toBeChecked();
});
