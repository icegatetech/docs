---
title: Development Patterns
description: Standard patterns used across the IceGate codebase
---

# Development Patterns

This document defines the standard patterns used across the IceGate codebase for config, errors, HTTP routes, handlers, and services.

## 1. Config Pattern

**File:** `{module}/config.rs`

```rust
//! Configuration for {MODULE}.

use serde::{Deserialize, Serialize};
use icegate_common::config::ServerConfig;

const DEFAULT_HOST: &str = "0.0.0.0";
const DEFAULT_PORT: u16 = 4318;

/// Configuration for {MODULE} server.
#[derive(Debug, Clone, Serialize, Deserialize)]
#[serde(default)]
pub struct ModuleConfig {
    pub enabled: bool,
    pub host: String,
    pub port: u16,
}

impl Default for ModuleConfig {
    fn default() -> Self {
        Self {
            enabled: true,
            host: DEFAULT_HOST.to_string(),
            port: DEFAULT_PORT,
        }
    }
}

impl ServerConfig for ModuleConfig {
    fn name(&self) -> &'static str { "Module Name" }
    fn enabled(&self) -> bool { self.enabled }
    fn port(&self) -> u16 { self.port }
}

impl ModuleConfig {
    pub fn validate(&self) -> Result<()> {
        // Validation logic
        Ok(())
    }
}
```

**Key points:**

- Use `#[derive(Debug, Clone, Serialize, Deserialize)]`
- Use `#[serde(default)]` at struct level
- Use `#[serde(rename_all = "lowercase")]` for enum variants
- Implement `ServerConfig` trait for port validation
- Implement `validate()` method for custom validation
- Define constants for default values

## 2. Crate Error Pattern

**File:** `{crate}/src/error.rs`

```rust
//! Error types for {CRATE}.

use std::io;

/// Result type for {CRATE} operations.
pub type Result<T> = std::result::Result<T, CrateError>;

/// Errors for {CRATE} operations.
#[derive(Debug, thiserror::Error)]
pub enum CrateError {
    #[error("decode error: {0}")]
    Decode(String),

    #[error("{0}")]
    Validation(String),

    #[error("not implemented: {0}")]
    NotImplemented(String),

    #[error("configuration error: {0}")]
    Config(String),

    #[error("io error: {0}")]
    Io(#[from] io::Error),

    #[error("iceberg error: {0}")]
    Iceberg(#[from] iceberg::Error),
}

// Cross-crate conversion
impl From<icegate_common::error::CommonError> for CrateError {
    fn from(err: icegate_common::error::CommonError) -> Self {
        use icegate_common::error::CommonError;
        match err {
            CommonError::Config(msg) => Self::Config(msg),
            CommonError::Iceberg(e) => Self::Iceberg(e),
            // ... other conversions
        }
    }
}
```

**Key points:**

- Use `thiserror = "2"` for derive macro
- Define `Result<T>` type alias
- Use `#[from]` for automatic `From` implementations
- Implement manual `From` for cross-crate error conversion

## 3. HTTP Transport Error Pattern

**File:** `{module}/error.rs`

```rust
//! HTTP error handling for {MODULE} API.

use axum::{http::StatusCode, response::{IntoResponse, Response}, Json};
use super::models::{ErrorResponse, ErrorType};
use crate::error::CrateError;

/// Result type for {MODULE} handlers.
pub type ModuleResult<T> = Result<T, ModuleError>;

/// Newtype wrapper implementing `IntoResponse`.
#[derive(Debug)]
pub struct ModuleError(pub CrateError);

impl From<CrateError> for ModuleError {
    fn from(err: CrateError) -> Self { Self(err) }
}

impl IntoResponse for ModuleError {
    fn into_response(self) -> Response {
        let (status, error_type) = match &self.0 {
            CrateError::Decode(_) | CrateError::Validation(_) =>
                (StatusCode::BAD_REQUEST, ErrorType::BadData),
            CrateError::NotImplemented(_) =>
                (StatusCode::NOT_IMPLEMENTED, ErrorType::NotImplemented),
            _ => (StatusCode::INTERNAL_SERVER_ERROR, ErrorType::Internal),
        };
        (status, Json(ErrorResponse::new(error_type, self.0.to_string()))).into_response()
    }
}
```

**Key points:**

- Create newtype wrapper around crate error
- Implement `From<CrateError>` for ergonomic `?` usage
- Implement `IntoResponse` for automatic HTTP response conversion
- Map error variants to appropriate HTTP status codes

## 4. gRPC Transport Error Pattern

**File:** `{module}/error.rs`

```rust
//! gRPC error handling for {MODULE} API.

use tonic::{Code, Status};
use crate::error::CrateError;

#[derive(Debug)]
pub struct GrpcError(pub CrateError);

impl From<CrateError> for GrpcError {
    fn from(err: CrateError) -> Self { Self(err) }
}

impl From<GrpcError> for Status {
    fn from(err: GrpcError) -> Self {
        let (code, msg) = match &err.0 {
            CrateError::Decode(_) | CrateError::Validation(_) =>
                (Code::InvalidArgument, err.0.to_string()),
            CrateError::NotImplemented(_) =>
                (Code::Unimplemented, err.0.to_string()),
            _ => (Code::Internal, err.0.to_string()),
        };
        Self::new(code, msg)
    }
}
```

**Key points:**

- Create newtype wrapper around crate error
- Implement `From<GrpcError> for Status` for tonic integration
- Map error variants to appropriate gRPC status codes

## 5. Response Models Pattern

**File:** `{module}/models.rs`

```rust
//! Response models for {MODULE} API.

use serde::Serialize;

#[derive(Debug, Serialize, Clone, Copy)]
#[serde(rename_all = "lowercase")]
pub enum ResponseStatus { Success, Error }

#[derive(Debug, Serialize, Clone, Copy)]
#[serde(rename_all = "snake_case")]
pub enum ErrorType { BadData, NotImplemented, Internal }

#[derive(Debug, Serialize)]
pub struct ErrorResponse {
    pub error: String,
    #[serde(rename = "errorType")]
    pub error_type: ErrorType,
}

impl ErrorResponse {
    pub fn new(error_type: ErrorType, message: impl Into<String>) -> Self {
        Self { error: message.into(), error_type }
    }
}
```

**Key points:**

- Use typed enums for status and error types
- Use `#[serde(rename_all = "...")]` for JSON field naming
- Provide constructor methods for ergonomic creation

## 6. Handler Pattern

**File:** `{module}/handlers.rs`

```rust
pub async fn handler_name(
    State(state): State<ModuleState>,
    headers: HeaderMap,
    Query(params): Query<ParamsStruct>,
) -> ModuleResult<impl IntoResponse> {
    // Extract tenant from headers
    let tenant_id = extract_tenant_id(&headers);

    // Process request
    let result = process(&state, &params).await?;

    Ok((StatusCode::OK, Json(Response::success(result))))
}
```

**Key points:**

- Use typed extractors: `State<T>`, `Query<T>`, `Path<T>`, `HeaderMap`
- Return `ModuleResult<impl IntoResponse>` for error handling
- Use `?` operator for error propagation
- Return tuple `(StatusCode, Json<T>)` for response

## 7. Server/Routes Pattern

**File:** `{module}/server.rs`

```rust
#[derive(Clone)]
pub struct ModuleState {
    pub resource: Arc<SharedResource>,
}

pub async fn run(
    resource: Arc<SharedResource>,
    config: ModuleConfig,
    cancel_token: CancellationToken,
) -> Result<(), Box<dyn std::error::Error + Send + Sync>> {
    let addr: SocketAddr = format!("{}:{}", config.host, config.port).parse()?;
    let state = ModuleState { resource };
    let app = super::routes::routes(state);

    let listener = tokio::net::TcpListener::bind(addr).await?;
    axum::serve(listener, app)
        .with_graceful_shutdown(async move { cancel_token.cancelled().await })
        .await?;
    Ok(())
}
```

**File:** `{module}/routes.rs`

```rust
pub fn routes(state: ModuleState) -> Router {
    Router::new()
        .route("/v1/endpoint", post(handlers::endpoint_handler))
        .route("/health", get(handlers::health))
        .with_state(state)
}
```

**Key points:**

- State struct must derive `Clone`
- Use `Arc<T>` for shared resources
- Use `CancellationToken` for graceful shutdown
- Separate routes into dedicated module
- Use `with_state()` to inject state into router

## Summary

| Component | Pattern |
|-----------|---------|
| Config | Derives + `ServerConfig` trait + `validate()` |
| Crate Errors | `thiserror` + `Result` alias + `From` impls |
| HTTP Errors | Newtype + `IntoResponse` |
| gRPC Errors | Newtype + `Into<Status>` |
| Models | Typed response envelopes |
| Handlers | Typed extractors + `Result` return |
| Routes | Router builder with state |
| Servers | `CancellationToken` shutdown |
