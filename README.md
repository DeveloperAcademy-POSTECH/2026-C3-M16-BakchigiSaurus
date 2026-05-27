# 2026-C3-M16-BakchigiSaurus

<img width="500" height="auto" alt="Image" src="https://github.com/user-attachments/assets/d2b1b41c-ca95-4b91-96fe-664e76aee3d5" />

> 고산, 카야, 하지, 살룻, 라나키, 캄초

[![Swift](https://img.shields.io/badge/Swift-5.9-orange.svg)]()
[![Xcode](https://img.shields.io/badge/Xcode-26.5-blue.svg)]()

---

## 🗂 목차
- [소개](#소개)
- [프로젝트 기간](#프로젝트-기간)
- [기술 스택](#기술-스택)
<!-- - [기능](#기능)
- [시연](#시연) -->
- [폴더 구조](#폴더-구조)
- [팀 소개](#팀-소개)
- [Git 컨벤션](#git-컨벤션)
- [테스트 방법](#테스트-방법)
<!-- - [프로젝트 문서](#프로젝트-문서)
- [라이선스](#lock_with_ink_pen-license) -->

---

## 📱 소개

> 숨바꼭질의 긴장감과 몰입도를 높이고 싶은상황에서
Multipeer Connectivity, Nearby Interaction기술을 통해, 가까운 플레이어를 연결하고 서로 탐지할 수 있게 해주는 앱


## 📆 프로젝트 기간
- 전체 기간: `2026.05.06 - 2026.06.12`
- 개발 기간: `2026.05.28 - `


## 🛠 기술 스택

- Swift / SwiftUI
- 아키텍처: MVVM
- 기타 도구: Figma


## 🌟 주요 기능

- Multipeer Connectivity로 사용자 연결
- Nearby Interaction을 활용한 술래 힌트기능
- 술래 근접시 카메라 녹화 및 취합


<!-- ## 🖼 화면 구성 및 시연

| 기능 | 설명 | 이미지 |
|------|------|--------|
| 예시1 | 기능 요약 | ![gif](링크) |
| 예시2 | 기능 요약 | ![gif](링크) | -->


## 🧱 폴더 구조

```text
HideAndSeek/
│
├── App/
│
├── Core/
│   ├── Networking/
│   ├── Proximity/
│   ├── Capture/
│   ├── Motion/
│   └── Models/
│
├── Features/
│   ├── Title/
│   ├── Home/
│   ├── Room/
│   ├── Game/
│   │   ├── Tagger/
│   │   └── Hider/
│   └── Result/
│
├── Shared/
│
└── Resources/
```


## 🧑‍💻 팀 소개

| 이름 | 역할 | GitHub |
|------|------|--------|
| 고산 | Developer |  |
| 카야 | Developer |  |
| 하지 | Developer |  |
| 살룻 | Developer |  |
| 캄초 | Developer |  |
| 라나키 | Designer |  |


## 🔖 브랜치 전략

- `main`: 배포 가능한 안정 버전
- `develop`: 통합 개발 브랜치
- `feat/*`: 기능 개발 브랜치
- `bugfix/*`: 버그 수정 브랜치
- `hotfix/*`: 긴급 수정 브랜치

## 🌀 커밋 메시지 컨벤션

[Conventional Commits](https://www.conventionalcommits.org)

### 예시
- feat: 로그인 화면 추가
- fix: 홈 진입 시 크래시 수정


## ✅ 테스트 방법

1. 이 저장소를 클론합니다.
```bash
git clone https://github.com/DeveloperAcademy-POSTECH/2026-C3-M16-BakchigiSaurus.git
```
2. `Xcode`로 `.xcodeproj` 또는 `.xcworkspace` 열기
3. 시뮬레이터 환경 설정: iPhone 17 / iOS 26.5
4. `Cmd + R`로 실행 / `Cmd + U`로 테스트 실행


<!-- ## 📎 프로젝트 문서

- [기획 히스토리](링크)
- [디자인 히스토리](링크)
- [기술 문서 (아키텍처 등)](링크) -->


<!-- ## 📝 License

This project is licensed under the ~~[CHOOSE A LICENSE](https://choosealicense.com). and update this line~~ --> 
