"""Shared field types and validation rules for recipes and release catalogs."""
from __future__ import annotations

import re
from typing import TypedDict, cast
from urllib.parse import urlsplit


class ValidationError(ValueError):
    pass


class Source(TypedDict):
    repository: str
    revision: str
    license: str


SOURCE_FIELDS = ('repository', 'revision', 'license')
RELEASE_VERSION_PATTERN = r'(?:0|[1-9]\d*)\.(?:0|[1-9]\d*)\.(?:0|[1-9]\d*)'


def mapping(value: object, context: str, required: tuple[str, ...] | None = None,
            optional: tuple[str, ...] = ()) -> dict[str, object]:
    if not isinstance(value, dict) or not all(isinstance(key, str) for key in value):
        raise ValidationError(f'{context} must be a mapping')
    if required is not None:
        for key in required:
            if key not in value:
                raise ValidationError(f'{context}.{key} is required')
        unknown = value.keys() - set(required) - set(optional)
        if unknown:
            raise ValidationError(f"{context}: unknown fields {', '.join(sorted(unknown))}")
    return cast('dict[str, object]', value)


def nonempty_string(value: object, context: str) -> str:
    if not isinstance(value, str) or not value.strip():
        raise ValidationError(f'{context} must be a nonempty string')
    return value


def string(value: object, context: str) -> str:
    text = nonempty_string(value, context)
    if text != text.strip() or re.search(r'[\r\n\x00]', text):
        raise ValidationError(f'{context} must be a nonempty string')
    return text


def app_id(value: object, context: str) -> str:
    text = string(value, context)
    if not re.fullmatch(r'[a-z][a-z0-9-]*', text):
        raise ValidationError(f'{context} must contain lowercase letters, digits or hyphens')
    return text


def release_version(value: object, context: str, *, allow_v: bool = False) -> str:
    text = string(value, context)
    candidate = text.removeprefix('v') if allow_v else text
    if not re.fullmatch(RELEASE_VERSION_PATTERN, candidate):
        prefix = '[v]' if allow_v else ''
        raise ValidationError(f'{context} must be a stable {prefix}MAJOR.MINOR.PATCH version without leading zeros')
    return text


def version_key(value: str) -> tuple[int, int, int]:
    major, minor, patch = map(int, release_version(value, 'version').split('.'))
    return major, minor, patch


def os_version(value: object, context: str) -> tuple[int, int, int]:
    text = string(value, context)
    if not re.fullmatch(r'[1-9]\d*(?:\.\d+){0,2}', text):
        raise ValidationError(f'{context} must be an OS version string')
    parts = tuple(map(int, text.split('.')))
    padded = parts + (0,) * (3 - len(parts))
    return padded[0], padded[1], padded[2]


def repository(value: object, context: str) -> str:
    text = string(value, context)
    try:
        url = urlsplit(text)
        valid = url.scheme == 'https' and url.hostname and url.path and '@' not in url.netloc
    except ValueError:
        valid = False
    if not valid or re.search(r'[\s?#]', text):
        raise ValidationError(f'{context} must be an HTTPS repository URL without credentials/query/fragment')
    return text


def git_revision(value: object, context: str) -> str:
    text = string(value, context)
    if not re.fullmatch(r'[0-9a-f]{40}', text):
        raise ValidationError(f'{context} must be a full 40-character lowercase Git commit')
    return text


def validate_source(value: object) -> Source:
    data = mapping(value, 'source')
    return {'repository': repository(data.get('repository'), 'source.repository'),
            'revision': git_revision(data.get('revision'), 'source.revision'),
            'license': nonempty_string(data.get('license'), 'source.license')}


def localized_description(value: object, context: str) -> dict[str, str]:
    data = mapping(value, context)
    if 'en' not in data:
        raise ValidationError(f'{context}.en is required as the fallback description')
    return {string(locale, f'{context} language'): string(text, f'{context}.{locale}')
            for locale, text in data.items()}
