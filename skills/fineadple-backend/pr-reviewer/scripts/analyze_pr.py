#!/usr/bin/env python3
"""
PR 분석 스크립트 (fineadple-server)

이 스크립트는 GitHub PR을 분석하여 코드 리뷰에 필요한 정보를 제공합니다:
- PR 메타데이터 (제목, 작성자, 브랜치, 파일 통계)
- 영향받는 모듈 감지
- 파일 분류 (source/test/config/migration/docs)
- 테스트 커버리지 체크
"""

import subprocess
import json
import sys
import argparse
from typing import List, Dict


# fineadple-server 프로젝트 모듈 목록
MODULES = [
    "fineadple_common",
    "fineadple_infrastructure",
    "fineadple_b2c_api",
    "fineadple_advertiser_center_api",
    "fineadple_authentication_api",
    "fineadple_backoffice_api",
    "fineadple_batch",
    "fineadple_crawler_api",
    "fineadple_notification_api",
    "fineadple_lambda",
]


def run_gh_command(command: List[str]) -> str:
    """gh CLI 명령 실행"""
    try:
        result = subprocess.run(
            command,
            capture_output=True,
            text=True,
            check=True
        )
        return result.stdout.strip()
    except subprocess.CalledProcessError as e:
        print(f"Error: gh CLI 명령 실행 실패: {e.stderr}", file=sys.stderr)
        sys.exit(1)


def fetch_pr_metadata(pr_number: int, repo: str) -> Dict:
    """PR 메타데이터 가져오기"""
    output = run_gh_command([
        "gh", "pr", "view", str(pr_number),
        "--repo", repo,
        "--json", "number,title,body,baseRefName,headRefName,files,additions,deletions,changedFiles,author,isDraft"
    ])

    if not output:
        print(f"Error: PR #{pr_number}을 찾을 수 없습니다.", file=sys.stderr)
        sys.exit(1)

    return json.loads(output)


def fetch_pr_files(metadata: Dict) -> List[str]:
    """PR에서 변경된 파일 경로 목록 추출"""
    files = metadata.get("files", [])
    return [f["path"] for f in files]


def detect_affected_modules(files: List[str]) -> List[str]:
    """변경된 파일에서 영향받는 모듈 감지"""
    affected = set()

    # 긴 모듈 이름부터 매칭하여 정확한 모듈 감지
    sorted_modules = sorted(MODULES, key=len, reverse=True)

    for file_path in files:
        for module in sorted_modules:
            if file_path.startswith(f"{module}/"):
                affected.add(module)
                break  # 가장 긴 매칭 모듈만 추가

    return sorted(affected)


def classify_files(files: List[str]) -> Dict[str, int]:
    """파일을 source/test/config/migration/docs로 분류"""
    classification = {
        "source": 0,
        "test": 0,
        "config": 0,
        "migration": 0,
        "docs": 0
    }

    for file_path in files:
        # 테스트 파일
        if "/test/" in file_path or file_path.endswith("Test.kt") or file_path.endswith("Test.java"):
            classification["test"] += 1
        # 설정 파일
        elif file_path.endswith((".yml", ".yaml", ".properties", ".xml")):
            classification["config"] += 1
        # 마이그레이션 파일
        elif file_path.endswith(".sql") or "liquibase" in file_path or "changeset" in file_path:
            classification["migration"] += 1
        # 문서 파일
        elif file_path.endswith(".md"):
            classification["docs"] += 1
        # 스크립트 파일
        elif file_path.endswith((".py", ".sh")):
            classification["source"] += 1
        # 빌드 파일
        elif file_path.endswith((".gradle", ".gradle.kts")):
            classification["config"] += 1
        # 소스 파일
        elif file_path.endswith((".kt", ".java")):
            classification["source"] += 1

    return classification


def detect_dependency_changes(files: List[str]) -> bool:
    """의존성 변경 감지"""
    gradle_files = [
        "build.gradle",
        "build.gradle.kts",
        "settings.gradle",
        "settings.gradle.kts",
        "gradle.properties",
    ]

    for file_path in files:
        if any(gradle in file_path for gradle in gradle_files):
            return True

    return False


def check_test_coverage(files: List[str]) -> bool:
    """변경된 source 파일에 대응하는 test 파일 존재 여부 확인"""
    source_files = [f for f in files if "/main/" in f and f.endswith((".kt", ".java"))]
    test_files = [f for f in files if "/test/" in f and f.endswith((".kt", ".java"))]

    # source 파일이 없으면 true (테스트가 필요 없음)
    if not source_files:
        return True

    # source 파일명에 대응하는 test 파일이 있는지 확인
    source_names = {f.split("/")[-1].replace(".kt", "").replace(".java", "") for f in source_files}
    test_names = {f.split("/")[-1].replace("Test.kt", "").replace("Test.java", "") for f in test_files}

    return bool(source_names & test_names)


def analyze_pr(pr_number: int, repo: str) -> Dict:
    """PR 분석 메인 함수"""
    # PR 메타데이터 가져오기
    metadata = fetch_pr_metadata(pr_number, repo)

    # 변경된 파일 목록
    changed_files = fetch_pr_files(metadata)

    # 영향받는 모듈 감지
    affected_modules = detect_affected_modules(changed_files)

    # 파일 분류
    file_classification = classify_files(changed_files)

    # 의존성 변경 감지
    has_dependency_changes = detect_dependency_changes(changed_files)

    # 테스트 커버리지 체크
    has_test_for_changes = check_test_coverage(changed_files)

    return {
        "pr_number": metadata["number"],
        "title": metadata["title"],
        "author": metadata["author"]["login"] if metadata.get("author") else "unknown",
        "base_branch": metadata["baseRefName"],
        "head_branch": metadata["headRefName"],
        "is_draft": metadata["isDraft"],
        "changed_files": changed_files,
        "affected_modules": affected_modules,
        "file_classification": file_classification,
        "has_dependency_changes": has_dependency_changes,
        "has_test_for_changes": has_test_for_changes,
        "additions": metadata["additions"],
        "deletions": metadata["deletions"],
        "total_files_changed": metadata["changedFiles"],
    }


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description="PR 분석 스크립트")
    parser.add_argument("--pr", type=int, required=True, help="PR 번호")
    parser.add_argument("--repo", type=str, default="herren-official/fineadple-server", help="GitHub 레포지토리 (owner/repo)")
    args = parser.parse_args()

    result = analyze_pr(args.pr, args.repo)
    print(json.dumps(result, indent=2, ensure_ascii=False))