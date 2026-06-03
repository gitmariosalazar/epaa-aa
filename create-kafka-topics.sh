#!/usr/bin/env bash
# =============================================================================
# create-kafka-topics.sh
# Crea todos los topics Kafka del proyecto epaa-aa.
# Uso:
#   ./create-kafka-topics.sh              # producción (kafka-epaa-prod)
#   ./create-kafka-topics.sh dev          # desarrollo  (kafka-epaa-dev)
# =============================================================================

set -euo pipefail

# ── Configuración ─────────────────────────────────────────────────────────────
ENV="${1:-prod}"

if [[ "$ENV" == "dev" ]]; then
  KAFKA_CONTAINER="kafka-epaa-dev"
  BOOTSTRAP="kafka-epaa-dev:9092"
else
  KAFKA_CONTAINER="kafka-epaa-prod"
  BOOTSTRAP="kafka-epaa-prod:9192"
fi

PARTITIONS=1
REPLICATION=1

# ── Helpers ───────────────────────────────────────────────────────────────────
create_topic() {
  local topic="$1"
  # Crea el topic; si ya existe, lo ignora silenciosamente
  docker exec "$KAFKA_CONTAINER" \
    kafka-topics --bootstrap-server "$BOOTSTRAP" \
    --create \
    --if-not-exists \
    --topic "$topic" \
    --partitions "$PARTITIONS" \
    --replication-factor "$REPLICATION" \
    2>&1 | grep -v "already exists" || true
  echo "  ✓ $topic"
}

echo ""
echo "=== Creando topics Kafka en [$KAFKA_CONTAINER] ==="
echo ""

# ── AUTHENTICATION ────────────────────────────────────────────────────────────
echo "--- authentication ---"
create_topic "authentication_topic"
create_topic "authentication.auth.signin"
create_topic "authentication.auth.client.signin"
create_topic "authentication.auth.signout"
create_topic "authentication.auth.refresh"
create_topic "authentication.auth.verify"
# customers
create_topic "authentication.customer.find_by_id"
create_topic "authentication.customer.find_by_client_id"
create_topic "authentication.customer.find_by_email"
create_topic "authentication.customer.create"
create_topic "authentication.customer.update"
create_topic "authentication.customer.soft_delete"
create_topic "authentication.customer.restore"
create_topic "authentication.customer.find_all"
create_topic "authentication.customer.send_verification_code"
create_topic "authentication.customer.verify_code"
create_topic "authentication.customer.resend_verification_code"
# users
create_topic "authentication.user.find_by_id"
create_topic "authentication.user.find_by_username_or_email"
create_topic "authentication.user.create_user"
create_topic "authentication.user.increment_failed_attempts"
create_topic "authentication.user.reset_failed_attempts"
create_topic "authentication.user.soft_delete"
create_topic "authentication.user.restore"
create_topic "authentication.user.update_user"
create_topic "authentication.user.update_password"
create_topic "authentication.user.verify_credentials"
create_topic "authentication.user.find_by_refresh_token"
create_topic "authentication.user.exists_by_username_or_email"
create_topic "authentication.user.exists_by_username"
create_topic "authentication.user.exists_by_email"
create_topic "authentication.user.find_by_username"
create_topic "authentication.user.find_by_email"
create_topic "authentication.user.find_all"
create_topic "authentication.user.get_profile"
create_topic "authentication.user.get_customer_profile"
create_topic "authentication.user.assign_role_to_user"
create_topic "authentication.user.remove_role_from_user"
create_topic "authentication.user.exists_role_in_user"
create_topic "authentication.user.get_users_by_role_id"
create_topic "authentication.user.get_roles_by_user_id"
create_topic "authentication.user.assign_permission_to_user"
create_topic "authentication.user.remove_permission_from_user"
create_topic "authentication.user.exists_permission_in_user"
create_topic "authentication.user.get_permissions_by_user_id"
create_topic "authentication.user.get_users_by_permission_id"
# user-employee
create_topic "authentication.user-employee.find_by_id"
create_topic "authentication.user-employee.find_by_user_id"
create_topic "authentication.user-employee.find_by_id_card"
create_topic "authentication.user-employee.search_by_name"
create_topic "authentication.user-employee.exists_by_user_id"
create_topic "authentication.user-employee.exists_by_id_card"
create_topic "authentication.user-employee.create"
create_topic "authentication.user-employee.update"
create_topic "authentication.user-employee.soft_delete"
create_topic "authentication.user-employee.restore"
create_topic "authentication.user-employee.assign_zones"
create_topic "authentication.user-employee.change_status"
create_topic "authentication.user-employee.change_supervisor"
create_topic "authentication.user-employee.find_all_active"
create_topic "authentication.user-employee.find_by_position"
create_topic "authentication.user-employee.find_by_zone"
create_topic "authentication.user-employee.find_by_supervisor"
create_topic "authentication.user-employee.find_all_employees"
# roles
create_topic "authentication.roles.get_rol_by_id"
create_topic "authentication.roles.get_all_rols"
create_topic "authentication.roles.create_rol"
create_topic "authentication.roles.update_rol"
# rol-permission
create_topic "authentication.rol_permission.create_rol_permission"
create_topic "authentication.rol_permission.delete_rol_permission"
create_topic "authentication.rol_permission.update_rol_permission"
create_topic "authentication.rol_permission.get_rol_permission_by_id"
create_topic "authentication.rol_permission.get_all_rol_permissions"
create_topic "authentication.rol_permission.verify_rol_permission_exists"
# permissions
create_topic "authentication.permission.verify-permission-exists-by-name"
create_topic "authentication.permission.get-permission-by-id"
create_topic "authentication.permission.get-all-permissions"
create_topic "authentication.permission.create-permission"
create_topic "authentication.permission.update-permission"
create_topic "authentication.permission.delete-permission"
create_topic "authentication.permission.get-permissions-with-category"
create_topic "authentication.permission.get-permissions-by-category-id"
create_topic "authentication.permission.get-permission-search-advanced"
# categories
create_topic "authentication.categories.create_category"
create_topic "authentication.categories.get_category_by_id"
create_topic "authentication.categories.get_all_categories"
create_topic "authentication.categories.update_category"
create_topic "authentication.categories.delete_category"
create_topic "authentication.categories.verify_category_existence"
create_topic "authentication.categories.search_category_by_name"
# audit
create_topic "audit.log-session"
create_topic "audit.get-logs"
create_topic "audit.get-session-logs"

# ── CLIENTS ───────────────────────────────────────────────────────────────────
echo "--- clients ---"
create_topic "clients_topic"
create_topic "customers.create-customer"
create_topic "customers.update-customer"
create_topic "customers.get-customer-by-id"
create_topic "customers.get-all-customers"
create_topic "customers.delete-customer"
create_topic "customers.verify-customer-exists"
create_topic "customers.get-general-customers"

# ── COMPANIES ─────────────────────────────────────────────────────────────────
echo "--- companies ---"
create_topic "companies_topic"
create_topic "companies.create-company"
create_topic "companies.update-company"
create_topic "companies.get-company-by-ruc"
create_topic "companies.get-all-companies"
create_topic "companies.delete-company"
create_topic "companies.verify-company-exists"

# ── CONNECTION ────────────────────────────────────────────────────────────────
echo "--- connection ---"
create_topic "connection_topic"
# connections
create_topic "connections.get-advance-dashboard-stats"
create_topic "connections.create-connection"
create_topic "connections.update-connection"
create_topic "connections.get-connection-by-id"
create_topic "connections.get-all-connections"
create_topic "connections.find-connections-by-sector"
create_topic "connections.find-connections-by-client-id"
create_topic "connections.delete-connection"
create_topic "connections.verify-connection-exists"
create_topic "connections.find-connection-by-property-cadastral-key"
create_topic "connections.find-connection-by-cadastral-key-or-card-id"
create_topic "connections.find-connection-with-property-by-cadastral-key"
create_topic "connections.get-all-connections-with-property"
create_topic "connections.get-connections-paginated"
create_topic "connections.change-connection-state"
create_topic "connections.get-connection-state-history"
create_topic "connections.get-connections-by-state"
create_topic "connections.get-state-summary-dashboard"
create_topic "connections.bulk-change-connection-state"
# requests
create_topic "requests.create_request"
create_topic "requests.get_request_by_id"
create_topic "requests.get_all_requests"
create_topic "requests.update_request"
create_topic "requests.delete_request"
create_topic "requests.get_expediente"
create_topic "requests.get_expedientes_by_cliente"
create_topic "requests.get_expedientes_by_analista"
create_topic "requests.get_historial"
create_topic "requests.get_dashboard_kpis"
create_topic "requests.get_ordenes_trabajo"
create_topic "requests.submit_request"
create_topic "requests.submit_with_documents"
create_topic "requests.get_tracking"
create_topic "requests.get_tracking_by_analista_id"
create_topic "requests.get_tracking_by_solicitud_id"
create_topic "requests.get_request_detail_by_request_id_or_number"
# installation & inspection orders
create_topic "installation_order.issue"
create_topic "installation_order.start"
create_topic "installation_order.complete"
create_topic "installation_order.fail"
create_topic "inspection_order.issue"
create_topic "inspection_order.start"
# inspection invoice
create_topic "inspection-invoice.create"
create_topic "inspection-invoice.getById"
create_topic "inspection-invoice.findAll"
create_topic "inspection-invoice.findAllByRequestId"
create_topic "inspection-invoice.delete"
create_topic "inspection-invoice.update"
# inspection report
create_topic "inspection_report.submit"
create_topic "inspection_report.approve"
# payment & documents
create_topic "payment_confirmation.confirm_payment"
create_topic "document_validation.validate_documents"
create_topic "connection-documents.create"
create_topic "connection-documents.update"
create_topic "connection-documents.get_by_id"
create_topic "connection-documents.get_all"
create_topic "connection-documents.get_by_client_id"
create_topic "connection-documents.get_by_request_id"
create_topic "connection-documents.delete"
# photos & observations
create_topic "photo-connection.create-photo-connection"
create_topic "photo-connection.get-photo-connections-by-cadastral-key"
create_topic "observation-connection.create-observation-connection"
create_topic "observation-connection.get-observation-connections-by-observation-id"
create_topic "observation-connection.get-observation-connections-by-connection-id"
create_topic "observation-connection.get-all-observation-connections"
# rates, contracts, cadastral
create_topic "rates.get-all-current-rates"
create_topic "contracts.generate"
create_topic "contracts.sign"
create_topic "cadastral.register_and_activate"

# ── DOCUMENTS ─────────────────────────────────────────────────────────────────
echo "--- documents ---"
create_topic "documents_topic"
create_topic "documents.get-types"
create_topic "documents.create-metadata"
create_topic "documents.get-by-id"
create_topic "documents.update-state"
create_topic "documents.associate"
create_topic "documents.get-by-entity"

# ── EPAA DATABASE LEGACY ──────────────────────────────────────────────────────
echo "--- epaa-database-legacy ---"
create_topic "epaa_database_legacy_topic"
# accounting
create_topic "epaa-legacy.accounting.get-daily-grouped-report"
create_topic "epaa-legacy.accounting.get-daily-collector-summary"
create_topic "epaa-legacy.accounting.get-daily-payment-method-report"
create_topic "epaa-legacy.accounting.get-full-breakdown-report"
create_topic "epaa-legacy.accounting.find-all-overdue-payments"
create_topic "epaa-legacy.accounting.find-overdue-summary"
create_topic "epaa-legacy.accounting.find-yearly-overdue-summary"
create_topic "epaa-legacy.accounting.find-monthly-debt-summary"
create_topic "epaa-legacy.accounting.find-pending-readings-by-card-id"
create_topic "epaa-legacy.accounting.get-general-collection-kpi"
create_topic "epaa-legacy.accounting.get-general-collection-report"
create_topic "epaa-legacy.accounting.get-general-yearly-collection-kpi"
create_topic "epaa-legacy.accounting.get-general-monthly-collection-kpi"
create_topic "epaa-legacy.accounting.get-agreements-kpi"
create_topic "epaa-legacy.accounting.get-agreements-kpi-customer"
create_topic "epaa-legacy.accounting.get-agreement-installment-details"
create_topic "epaa-legacy.accounting.get-monthly-collection-summary"
create_topic "epaa-legacy.accounting.get-debtors-with-risk"
create_topic "epaa-legacy.accounting.get-collector-performance"
create_topic "epaa-legacy.accounting.get-payment-method-summary"
create_topic "epaa-legacy.accounting.get-citizen-summary"
# readings legacy
create_topic "epaa-legacy.reading.create-reading-legacy"
create_topic "epaa-legacy.reading.find-current-reading"
create_topic "epaa-legacy.reading.update-current-reading"
create_topic "epaa-legacy.reading.calculate-reading-value"
# trash
create_topic "trash-rate-audit-report"
create_topic "credit-notes"
create_topic "missing-valor-records"
create_topic "monthly-summary"
create_topic "top-debtors"
create_topic "trash-dashboard-kpi"
create_topic "client-trash-detail"
create_topic "trash-rate-kpi"
create_topic "collector-performance-kpi"
create_topic "daily-collector-detail"

# ── LOCATION ──────────────────────────────────────────────────────────────────
echo "--- location ---"
create_topic "location_topic"
create_topic "location.get-countries"
create_topic "location.get-country-by-id"
create_topic "location.get-country-by-name"
create_topic "location.get-provinces"
create_topic "location.get-province-by-name"
create_topic "location.get-province-by-id"
create_topic "location.get-provinces-by-country-id"
create_topic "location.get-cantons"
create_topic "location.get-canton-by-id"
create_topic "location.get-canton-by-name"
create_topic "location.get-cantons-by-province-id"
create_topic "location.get-parishes"
create_topic "location.get-parish-by-name"
create_topic "location.get-parishes-by-canton-id"
create_topic "location.get-parish-by-id"

# ── NOTIFICATIONS ─────────────────────────────────────────────────────────────
echo "--- notifications ---"
create_topic "notifications_topic"
create_topic "notifications.send"
create_topic "notifications.get_unread"
create_topic "notifications.get_all"
create_topic "notifications.get_unread_count"
create_topic "notifications.mark_as_read"
create_topic "notifications.mark_all_as_read"
create_topic "notifications.acometidas.docs_rechazados"
create_topic "notifications.acometidas.informe_rechazado"
create_topic "notifications.acometidas.suministro_activo"
create_topic "notifications.acometidas.docs_submitted"
create_topic "notifications.acometidas.acometida_confirmacion"

# ── PROPERTY ──────────────────────────────────────────────────────────────────
echo "--- property ---"
create_topic "property_topic"
create_topic "properties.create-property"
create_topic "properties.update-property"
create_topic "properties.get-property-by-id"
create_topic "properties.get-all-properties"
create_topic "properties.delete-property"
create_topic "properties.verify-property-exists"
create_topic "properties.get-properties-by-owner"
create_topic "properties.get-properties-by-type"

# ── QRCODE ────────────────────────────────────────────────────────────────────
echo "--- qrcode ---"
create_topic "qrcode_topic"
create_topic "qrcode.create"
create_topic "qrcode.find-qrcode-by-acometidaId"

# ── READINGS ──────────────────────────────────────────────────────────────────
echo "--- readings ---"
create_topic "readings_topic"
create_topic "reading.find-basic-reading"
create_topic "reading.update-current-reading"
create_topic "reading.create-reading"
create_topic "reading.find-reading-info"
create_topic "reading.find-reading-history"
create_topic "reading.get-pending-readings-by-month"
create_topic "reading.get-taken-reading-estimates-or-average"
create_topic "reading.get-taken-readings-by-month"
create_topic "reading.get-reading-by-novelty"
create_topic "reading.find-reading-images-by-month"
create_topic "reading.find-reading-images-by-month-and-sector"
create_topic "reading.find-readings-image-by-cadastral-key"
create_topic "reading.find-all-reading-images"
create_topic "reading.audit.initialize-monthly"
create_topic "reading.audit.by-month"
create_topic "reading.audit.by-sector-and-month"
create_topic "reading.audit.close-sector"
create_topic "reading.audit.history-by-sector"
create_topic "reading.report.connection.last-10"
create_topic "reading.report.daily"
create_topic "reading.report.yearly"
create_topic "reading.dashboard.metrics"
create_topic "reading.report.stats.global"
create_topic "reading.report.stats.daily"
create_topic "reading.report.stats.sector"
create_topic "reading.report.stats.novelty"
create_topic "reading.report.advanced-monthly"

# ── SIGAME LEGACY ─────────────────────────────────────────────────────────────
echo "--- sigame-legacy ---"
create_topic "sigame_legacy_topic"
create_topic "inventory_topic"
create_topic "inventory.get-inventory-by-id"
create_topic "inventory.get-all-inventories"
create_topic "inventory.get-inventories-below-min-stock"
create_topic "inventory.get-inventories-by-account-code"
create_topic "inventory.get-inventories-by-company-code"
create_topic "inventory.get-inventories-by-status"
create_topic "inventory.get-inventories-by-item-type"
create_topic "inventory.get-inventories-by-unit-of-measure"
create_topic "inventory.get-inventories-like-item-name"
create_topic "inventory.get-inventories-like-item-code"
create_topic "inventory.find-all-inventories-paginated"

# ── WORK ORDERS ───────────────────────────────────────────────────────────────
echo "--- work-orders ---"
create_topic "work_orders_topic"
create_topic "work-orders.create-work-order"
create_topic "work-orders.update-work-order"
create_topic "work-orders.get-work-order-by-order-code"
create_topic "work-orders.get-work-orders-by-client-id"
create_topic "work-orders.get-all-work-orders"
create_topic "work-orders.get-all-work-orders-full-details"
create_topic "work-orders.get-work-order-statistics"
create_topic "work-orders.get-work-order-assignments"
create_topic "work-orders.get-work-order-materials"
create_topic "work-orders.get-work-order-observations"
create_topic "work-orders.get-work-order-attachments"
create_topic "work-orders.get-work-orders-by-client"
create_topic "work-orders.find-work-orders-full-details-by-order-code"
create_topic "work-orders.get-work-order-priority-statistics"
create_topic "work-orders.get-work-order-status-statistics"
create_topic "work-orders.get-work-order-type-statistics"
create_topic "work-orders.get-work-orders-statistics-key"
# work-order-attachments
create_topic "work-order-attachments.add_work_order_attachment"
create_topic "work-order-attachments.find_all_attachments"
create_topic "work-order-attachments.get_work_order_attachment_by_id"
create_topic "work-order-attachments.delete_work_order_attachment"
create_topic "work-order-attachments.update_work_order_attachment"
create_topic "work-order-attachments.find_attachments_by_work_order_id"
# worker assignments
create_topic "assignment-worker.add_worker_assignment_to_work_order_list"
create_topic "assignment-worker.find_worker_assignment_by_worker_id"
create_topic "assignment-worker.find_worker_assignments_by_work_order_id"
# observations
create_topic "work-orders-observations.create-work-order-observation"
create_topic "work-orders-observations.update-work-order-observation"
create_topic "work-orders-observations.get-work-order-observation-by-id"
create_topic "work-orders-observations.get-all-work-order-observations"
# history
create_topic "work-orders-histories.create-work-order-history"
create_topic "work-orders-histories.update-work-order-history"
create_topic "work-orders-histories.get-work-order-history-by-id"
create_topic "work-orders-histories.get-all-work-order-histories"
create_topic "work-orders-histories.find-all-view-histories-work-orders"
# work-type
create_topic "work-type.create-work-type"
create_topic "work-type.update-work-type"
create_topic "work-type.get-work-type-by-id"
create_topic "work-type.get-all-work-types"
create_topic "work-type.verify-work-type-exists-by-name"
create_topic "work-type.find-work-types-by-department-id"
# materials
create_topic "detail_work_order_material.add_detail_work_order_materials"

# ── WORKERS ───────────────────────────────────────────────────────────────────
echo "--- workers ---"
create_topic "workers_topic"
create_topic "workers.find-all-workers"
create_topic "workers.find-all-workers-paginated"

# ── Reply topics (request-reply pattern de ClientKafka) ───────────────────────
echo "--- reply topics ---"
# NestJS ClientKafka crea automáticamente los .reply, pero pre-crearlos evita
# el error UNKNOWN_TOPIC_OR_PARTITION en el primer arranque
for base_topic in \
  "authentication.auth.signin" \
  "authentication.auth.client.signin" \
  "authentication.auth.signout" \
  "authentication.auth.refresh" \
  "authentication.auth.verify" \
  "inspection-invoice.create" \
  "inspection-invoice.getById" \
  "inspection-invoice.findAll" \
  "inspection-invoice.findAllByRequestId" \
  "inspection-invoice.delete" \
  "inspection-invoice.update" \
  "requests.create_request" \
  "requests.get_request_by_id" \
  "requests.get_all_requests" \
  "requests.submit_request" \
  "requests.get_tracking" \
  "connections.create-connection" \
  "connections.get-connection-by-id" \
  "documents.create-metadata" \
  "documents.get-by-id" \
  "customers.create-customer" \
  "customers.get-customer-by-id" \
  "notifications.send"; do
  create_topic "${base_topic}.reply"
done

echo ""
echo "=== Todos los topics creados correctamente ==="
echo ""

# Opcional: listar todos los topics creados
echo "Topics existentes en Kafka:"
docker exec "$KAFKA_CONTAINER" \
  kafka-topics --bootstrap-server "$BOOTSTRAP" --list | sort
