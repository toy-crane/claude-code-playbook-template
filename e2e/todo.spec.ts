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

test("같은 자리에서 이어 누른 두 번째 클릭은 같은 제스처로 취급해 삼킨다", async ({
  page,
}) => {
  await add(page, "1번");
  await add(page, "2번");
  await add(page, "3번");

  // Playwright 의 click() 은 항상 clickCount 1 을 보내므로 브라우저의 클릭 계수가
  // 개입하지 않는다. 실제 사용자의 연타를 재현하려면 clickCount 를 직접 준다.
  const button = page.getByRole("button", { name: "3번 삭제" });
  const box = (await button.boundingBox())!;
  const x = box.x + box.width / 2;
  const y = box.y + box.height / 2;

  await page.mouse.move(x, y);
  await page.mouse.down({ clickCount: 1 });
  await page.mouse.up({ clickCount: 1 });
  await page.mouse.down({ clickCount: 2 });
  await page.mouse.up({ clickCount: 2 });

  // 실수로 두 항목이 사라지는 것을 막는 대신, 같은 자리에서 곧바로 이어 누른
  // 삭제는 무시된다. 되돌리기가 없으므로 잃는 쪽을 막는 절충이다.
  await expect(page.getByRole("listitem")).toHaveText([/2번/, /1번/]);
});

test("자리를 옮겨 누르면 여러 항목을 차례로 지울 수 있다", async ({ page }) => {
  await add(page, "1번");
  await add(page, "2번");
  await add(page, "3번");

  // 다른 행의 삭제 버튼으로 포인터가 옮겨 가면 브라우저가 클릭 계수를 되돌린다.
  const first = (await page
    .getByRole("button", { name: "3번 삭제" })
    .boundingBox())!;
  await page.mouse.move(first.x + first.width / 2, first.y + first.height / 2);
  await page.mouse.down({ clickCount: 1 });
  await page.mouse.up({ clickCount: 1 });

  const second = (await page
    .getByRole("button", { name: "1번 삭제" })
    .boundingBox())!;
  await page.mouse.move(second.x + second.width / 2, second.y + second.height / 2);
  await page.mouse.down({ clickCount: 1 });
  await page.mouse.up({ clickCount: 1 });

  await expect(page.getByRole("listitem")).toHaveText([/2번/]);
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

test("편집 내용이 여러 줄로 접혀도 아래 항목을 더블클릭해 바로 편집할 수 있다", async ({
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
  await page.getByText("아래 항목").dblclick();

  await expect(page.getByRole("textbox", { name: "할 일 수정" })).toHaveValue(
    "아래 항목"
  );
  await expect(page.getByText("두 줄 이상으로 접히도록")).toBeVisible();
});

test("편집 중 다른 항목의 글자를 한 번 클릭하면 편집 내용이 저장된다", async ({
  page,
}) => {
  await add(page, "아래 항목");
  await add(page, "위 항목");

  await page.getByText("위 항목").dblclick();
  await page.getByRole("textbox", { name: "할 일 수정" }).fill("위 항목 고침");
  await page.getByText("아래 항목").click();

  await expect(page.getByRole("textbox", { name: "할 일 수정" })).toHaveCount(0);
  await expect(page.getByRole("listitem")).toHaveText([
    /위 항목 고침/,
    /아래 항목/,
  ]);
});

test("편집 중이 아닐 때 체크박스를 클릭하면 포커스를 받는다", async ({
  page,
}) => {
  await add(page, "장보기");

  await page.getByRole("checkbox", { name: "장보기" }).click();

  await expect(page.getByRole("checkbox", { name: "장보기" })).toBeFocused();
});

test("저장된 값을 읽기만 하고 사용자가 조작하지 않으면 저장소를 덮어쓰지 않는다", async ({
  page,
}) => {
  // 모양이 맞지 않는 항목이 섞여 있어도, 페이지를 열기만 해서 원본이 사라지면 안 된다.
  const RAW = JSON.stringify([
    { id: "a", text: "정상 항목", done: false },
    { id: "b", text: "완료 값이 문자열", done: "true" },
  ]);
  await page.evaluate((raw) => localStorage.setItem("todo-app.todos", raw), RAW);
  await page.reload();

  await expect(page.getByRole("listitem")).toHaveText([/정상 항목/]);
  expect(
    await page.evaluate(() => localStorage.getItem("todo-app.todos"))
  ).toBe(RAW);
});

test("편집을 확정해도 행 높이가 변하지 않아 아래 항목이 밀리지 않는다", async ({
  page,
}) => {
  await add(page, "아래 항목");
  await add(page, "위 항목");

  const rowHeight = (index: number) =>
    page.evaluate(
      (i) => document.querySelectorAll("li")[i].getBoundingClientRect().height,
      index
    );
  const rowTop = (index: number) =>
    page.evaluate(
      (i) => document.querySelectorAll("li")[i].getBoundingClientRect().top,
      index
    );

  await page.getByText("위 항목").dblclick();
  await page
    .getByRole("textbox", { name: "할 일 수정" })
    .fill(
      "위 항목을 아주 길게 고쳐서 한 줄에 담기지 않고 두 줄 이상으로 접히도록 만든다 — 편집창도 같이 늘어나야 한다"
    );
  const heightWhileEditing = await rowHeight(0);
  const topBelowWhileEditing = await rowTop(1);

  await page.keyboard.press("Enter");

  // 편집창과 글자가 같은 높이여야, 확정 순간 아래 항목이 밀려 클릭이 엉뚱한
  // 곳에 떨어지는 일이 생기지 않는다.
  expect(Math.abs((await rowHeight(0)) - heightWhileEditing)).toBeLessThan(1);
  expect(Math.abs((await rowTop(1)) - topBelowWhileEditing)).toBeLessThan(1);
});

test("편집창에 줄바꿈이 든 값을 붙여넣어도 한 줄로 저장되고 행 높이가 유지된다", async ({
  page,
}) => {
  await add(page, "아래 항목");
  await add(page, "위 항목");

  const rowHeight = (index: number) =>
    page.evaluate(
      (i) => document.querySelectorAll("li")[i].getBoundingClientRect().height,
      index
    );

  await page.getByText("위 항목").dblclick();
  // 붙여넣기로 들어올 수 있는 값. 할 일은 추가 입력창으로 만들 수 있는 것과
  // 같게 한 줄이어야 한다.
  await page
    .getByRole("textbox", { name: "할 일 수정" })
    .fill("첫 줄\n둘째 줄\n");
  const heightWhileEditing = await rowHeight(0);
  await page.getByRole("heading", { level: 1 }).click();

  await expect(page.getByRole("listitem").first()).toHaveText("첫 줄 둘째 줄");
  expect(Math.abs((await rowHeight(0)) - heightWhileEditing)).toBeLessThan(1);
});

test("편집 중 화면 폭이 바뀌어도 편집창이 글자를 가리지 않는다", async ({
  page,
}) => {
  await add(
    page,
    "폭을 줄이면 여러 줄로 접혀야 하는 제법 긴 할 일 항목이다 — 창 크기를 바꿔 본다"
  );

  await page.getByText(/폭을 줄이면/).dblclick();
  await page.setViewportSize({ width: 420, height: 900 });

  await expect
    .poll(async () =>
      page.evaluate(() => {
        const area = document.querySelector("textarea")!;
        return area.scrollHeight - area.getBoundingClientRect().height;
      })
    )
    .toBeLessThan(1);
});
