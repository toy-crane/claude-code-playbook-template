import { expect, test, type Page } from "@playwright/test";

const NEW_TODO = "새 할 일";

async function add(page: Page, text: string) {
  const input = page.getByRole("textbox", { name: NEW_TODO });
  await input.fill(text);
  await input.press("Enter");
}

test.beforeEach(async ({ page }) => {
  await page.goto("/");
  await page.evaluate(() => localStorage.clear());
  await page.reload();
});

test("빈 목록 안내가 보이고, 항목을 추가하면 맨 위에 쌓인다", async ({ page }) => {
  await expect(page).toHaveTitle("할 일");
  await expect(page.getByText("할 일이 없습니다")).toBeVisible();

  await add(page, "장보기");
  await add(page, "우편물 찾기");

  await expect(page.getByText("할 일이 없습니다")).toBeHidden();
  await expect(page.getByRole("listitem")).toHaveText([
    /우편물 찾기/,
    /장보기/,
  ]);
});

test("새로고침해도 목록의 순서와 완료 상태가 유지된다", async ({ page }) => {
  await add(page, "장보기");
  await add(page, "우편물 찾기");
  await page.getByRole("checkbox", { name: "장보기" }).click();

  await page.reload();

  await expect(page.getByRole("listitem")).toHaveText([
    /우편물 찾기/,
    /장보기/,
  ]);
  await expect(page.getByRole("checkbox", { name: "장보기" })).toBeChecked();
  await expect(
    page.getByRole("checkbox", { name: "우편물 찾기" })
  ).not.toBeChecked();
});

test("새로고침 직후 빈 목록 안내가 스쳐 지나가지 않는다", async ({ page }) => {
  await add(page, "장보기");

  const seenEmptyGuide: boolean[] = [];
  await page.reload();
  // 항목이 그려질 때까지, 빈 목록 안내가 한 번이라도 보였는지 계속 확인한다.
  for (let i = 0; i < 40; i += 1) {
    seenEmptyGuide.push(
      await page.getByText("할 일이 없습니다").isVisible().catch(() => false)
    );
    if (await page.getByRole("listitem").first().isVisible().catch(() => false)) {
      break;
    }
  }

  await expect(page.getByRole("listitem")).toHaveText([/장보기/]);
  expect(seenEmptyGuide).not.toContain(true);
});

test("더블클릭으로 편집하고 Enter로 저장하면 새로고침 후에도 남는다", async ({
  page,
}) => {
  await add(page, "장보기");

  await page.getByText("장보기").dblclick();
  const edit = page.getByRole("textbox", { name: "할 일 수정" });
  await expect(edit).toBeFocused();
  await edit.fill("장보기 — 우유와 계란");
  await edit.press("Enter");

  await page.reload();
  await expect(page.getByRole("listitem")).toHaveText([/장보기 — 우유와 계란/]);
});

test("편집 중에 다른 항목의 체크박스를 한 번 누르면 편집 저장과 완료가 함께 일어난다", async ({
  page,
}) => {
  await add(page, "장보기");
  await add(page, "우편물 찾기");

  await page.getByText("우편물 찾기").dblclick();
  await page.getByRole("textbox", { name: "할 일 수정" }).fill("우편물 찾기 오늘");
  await page.getByRole("checkbox", { name: "장보기" }).click();

  await expect(page.getByRole("checkbox", { name: "장보기" })).toBeChecked();
  await expect(page.getByText("우편물 찾기 오늘")).toBeVisible();
});

test("편집 중인 항목의 삭제 버튼을 한 번 누르면 그 항목이 사라진다", async ({
  page,
}) => {
  await add(page, "장보기");
  await add(page, "우편물 찾기");

  await page.getByText("우편물 찾기").dblclick();
  await page.getByRole("textbox", { name: "할 일 수정" }).fill("버려질 편집");
  await page.getByRole("button", { name: "우편물 찾기 삭제" }).click();

  await expect(page.getByRole("listitem")).toHaveText([/장보기/]);
  await expect(page.getByText("버려질 편집")).toBeHidden();
});

test("삭제한 항목은 새로고침 후에도 돌아오지 않는다", async ({ page }) => {
  await add(page, "장보기");
  await add(page, "우편물 찾기");

  await page.getByRole("button", { name: "장보기 삭제" }).click();
  await page.reload();

  await expect(page.getByRole("listitem")).toHaveText([/우편물 찾기/]);
});

test("긴 내용과 공백 없는 URL이 화면을 가로로 밀지 않는다", async ({ page }) => {
  await add(
    page,
    "https://internal.example.com/wiki/onboarding/local-dev-environment-setup-guide-2026-revision-final-v3"
  );

  const overflow = await page.evaluate(
    () => document.documentElement.scrollWidth - window.innerWidth
  );
  expect(overflow).toBeLessThanOrEqual(0);
});

test("삭제 버튼을 실수로 연타해도 한 항목만 사라진다", async ({ page }) => {
  await add(page, "1번");
  await add(page, "2번");
  await add(page, "3번");

  // 첫 클릭으로 행이 사라지면 아래 항목이 커서 자리로 올라온다. 같은 더블클릭
  // 제스처의 두 번째 클릭이 그 항목을 지우면 되돌릴 방법이 없다.
  await page.getByRole("button", { name: "3번 삭제" }).dblclick();

  await expect(page.getByRole("listitem")).toHaveText([/2번/, /1번/]);
});

test("의도적으로 이어서 누르면 여러 항목을 차례로 지울 수 있다", async ({
  page,
}) => {
  await add(page, "1번");
  await add(page, "2번");
  await add(page, "3번");

  await page.getByRole("button", { name: "3번 삭제" }).click();
  await page.waitForTimeout(600);
  await page.getByRole("button", { name: "2번 삭제" }).click();

  await expect(page.getByRole("listitem")).toHaveText([/1번/]);
});

test("편집 내용이 여러 줄로 접혀도 아래 항목의 첫 클릭이 삼켜지지 않는다", async ({
  page,
}) => {
  await add(page, "아래 항목");
  await add(page, "위 항목");

  // 편집창은 한 줄이지만 저장된 글자는 여러 줄로 접힌다. 저장 시 행이 높아지며
  // 아래 항목이 밀려나, 클릭이 원래 버튼에 도달하지 못할 수 있다.
  await page.getByText("위 항목").dblclick();
  await page
    .getByRole("textbox", { name: "할 일 수정" })
    .fill(
      "위 항목을 아주 길게 고쳐서 한 줄에 담기지 않고 두 줄 이상으로 접히도록 만든다 — 편집창이 글자로 바뀌면 행 높이가 커진다"
    );
  await page.getByRole("button", { name: "아래 항목 삭제" }).click();

  await expect(page.getByRole("listitem")).toHaveText([/두 줄 이상으로 접히도록/]);
});

test("편집 내용이 여러 줄로 접혀도 아래 항목의 체크박스가 한 번에 눌린다", async ({
  page,
}) => {
  await add(page, "아래 항목");
  await add(page, "위 항목");

  await page.getByText("위 항목").dblclick();
  await page
    .getByRole("textbox", { name: "할 일 수정" })
    .fill(
      "위 항목을 아주 길게 고쳐서 한 줄에 담기지 않고 두 줄 이상으로 접히도록 만든다 — 편집창이 글자로 바뀌면 행 높이가 커진다"
    );
  await page.getByRole("checkbox", { name: "아래 항목" }).click();

  await expect(page.getByRole("checkbox", { name: "아래 항목" })).toBeChecked();
});
