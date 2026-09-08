#include "isar_symbols.h"

#define ISAR_SYMBOLS(X)                  \
  X(isar_clear)                          \
  X(isar_connect_dart_api)               \
  X(isar_count)                          \
  X(isar_delete)                         \
  X(isar_delete_all)                     \
  X(isar_delete_all_by_index)            \
  X(isar_delete_by_index)                \
  X(isar_filter_and_or_xor)              \
  X(isar_filter_double)                  \
  X(isar_filter_id)                      \
  X(isar_filter_link)                    \
  X(isar_filter_link_length)             \
  X(isar_filter_list_length)             \
  X(isar_filter_long)                    \
  X(isar_filter_not)                     \
  X(isar_filter_null)                    \
  X(isar_filter_object)                  \
  X(isar_filter_static)                  \
  X(isar_filter_string)                  \
  X(isar_filter_string_contains)         \
  X(isar_filter_string_ends_with)         \
  X(isar_filter_string_matches)          \
  X(isar_filter_string_starts_with)      \
  X(isar_find_word_boundaries)           \
  X(isar_free_c_object_set)              \
  X(isar_free_json)                      \
  X(isar_free_string)                    \
  X(isar_free_word_boundaries)           \
  X(isar_get)                            \
  X(isar_get_all)                        \
  X(isar_get_all_by_index)               \
  X(isar_get_by_index)                   \
  X(isar_get_error)                      \
  X(isar_get_offsets)                    \
  X(isar_get_size)                       \
  X(isar_instance_close)                 \
  X(isar_instance_close_and_delete)      \
  X(isar_instance_copy_to_file)          \
  X(isar_instance_create)                \
  X(isar_instance_create_async)          \
  X(isar_instance_get_collection)        \
  X(isar_instance_get_path)              \
  X(isar_instance_get_size)              \
  X(isar_instance_verify)                \
  X(isar_json_import)                    \
  X(isar_key_add_byte)                   \
  X(isar_key_add_byte_list_hash)         \
  X(isar_key_add_double)                 \
  X(isar_key_add_float)                  \
  X(isar_key_add_int)                    \
  X(isar_key_add_int_list_hash)          \
  X(isar_key_add_long)                   \
  X(isar_key_add_long_list_hash)         \
  X(isar_key_add_string)                 \
  X(isar_key_add_string_hash)            \
  X(isar_key_add_string_list_hash)       \
  X(isar_key_create)                     \
  X(isar_key_decrease)                   \
  X(isar_key_increase)                   \
  X(isar_link)                           \
  X(isar_link_unlink)                    \
  X(isar_link_unlink_all)                \
  X(isar_link_update_all)                \
  X(isar_link_verify)                    \
  X(isar_mdbx_version)                   \
  X(isar_put)                            \
  X(isar_put_all)                        \
  X(isar_put_all_by_index)               \
  X(isar_put_by_index)                   \
  X(isar_q_aggregate)                    \
  X(isar_q_aggregate_double_result)      \
  X(isar_q_aggregate_long_result)        \
  X(isar_q_delete)                       \
  X(isar_q_export_json)                  \
  X(isar_q_find)                         \
  X(isar_q_free)                         \
  X(isar_qb_add_distinct_by)             \
  X(isar_qb_add_id_where_clause)         \
  X(isar_qb_add_index_where_clause)      \
  X(isar_qb_add_link_where_clause)       \
  X(isar_qb_add_sort_by)                 \
  X(isar_qb_build)                       \
  X(isar_qb_create)                      \
  X(isar_qb_set_filter)                  \
  X(isar_qb_set_offset_limit)            \
  X(isar_stop_watching)                  \
  X(isar_txn_begin)                      \
  X(isar_txn_finish)                     \
  X(isar_verify)                         \
  X(isar_version)                        \
  X(isar_watch_collection)               \
  X(isar_watch_object)                   \
  X(isar_watch_query)

#define DECLARE_SYMBOL(symbol) extern void symbol(void);
ISAR_SYMBOLS(DECLARE_SYMBOL)

#define SYMBOL_ADDRESS(symbol) symbol,
static void (*const isar_symbols[])(void) = {ISAR_SYMBOLS(SYMBOL_ADDRESS)};

void isar_keep_symbols(void) {
  for (unsigned long i = 0; i < sizeof(isar_symbols) / sizeof(isar_symbols[0]); i++) {
    __asm__ volatile("" : : "r"(isar_symbols[i]) : "memory");
  }
}
