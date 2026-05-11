package gyo.plugins.contact_search

import android.content.Context
import android.provider.ContactsContract
import android.util.Log
import gyo.plugins.bridge.BridgeHandler
import org.json.JSONArray
import org.json.JSONObject

class ContactSearchBridge(private val context: Context) : BridgeHandler {

    companion object {
        private const val TAG = "AIOS-ContactSearch"
    }

    override fun handle(method: String, data: JSONObject): Any? {
        return when (method) {
            "search" -> search(data)
            else -> {
                Log.w(TAG, "Unknown method: $method")
                null
            }
        }
    }

    private fun search(data: JSONObject): JSONObject {
        val query = data.optString("query", "").trim()
        if (query.isEmpty()) {
            Log.w(TAG, "search: query is empty")
            return JSONObject().apply {
                put("contacts", JSONArray())
                put("count", 0)
            }
        }

        val contacts = JSONArray()
        val projection = arrayOf(
            ContactsContract.CommonDataKinds.Email.CONTACT_ID,
            ContactsContract.Contacts.DISPLAY_NAME,
        )

        val selection = "${ContactsContract.Contacts.DISPLAY_NAME} LIKE ?"
        val selectionArgs = arrayOf("%$query%")

        val contactMap = mutableMapOf<Long, String>()

        try {
            context.contentResolver.query(
                ContactsContract.Contacts.CONTENT_URI,
                arrayOf(
                    ContactsContract.Contacts._ID,
                    ContactsContract.Contacts.DISPLAY_NAME,
                ),
                selection,
                selectionArgs,
                ContactsContract.Contacts.DISPLAY_NAME + " ASC",
            )?.use { cursor ->
                val idIndex = cursor.getColumnIndexOrThrow(ContactsContract.Contacts._ID)
                val nameIndex = cursor.getColumnIndexOrThrow(ContactsContract.Contacts.DISPLAY_NAME)

                while (cursor.moveToNext()) {
                    val contactId = cursor.getLong(idIndex)
                    val name = cursor.getString(nameIndex) ?: continue
                    contactMap[contactId] = name
                }
            }
        } catch (e: SecurityException) {
            Log.e(TAG, "search: READ_CONTACTS permission not granted", e)
            return JSONObject().apply {
                put("contacts", JSONArray())
                put("count", 0)
            }
        } catch (e: Exception) {
            Log.e(TAG, "search: failed to query contacts", e)
            return JSONObject().apply {
                put("contacts", JSONArray())
                put("count", 0)
            }
        }

        for ((contactId, name) in contactMap) {
            val phoneNumbers = getPhoneNumbers(contactId)
            val emails = getEmails(contactId)

            val contactInfo = JSONObject().apply {
                put("id", contactId.toString())
                put("name", name)
                put("phoneNumbers", phoneNumbers)
                put("emails", emails)
            }
            contacts.put(contactInfo)
        }

        return JSONObject().apply {
            put("contacts", contacts)
            put("count", contacts.length())
        }
    }

    private fun getPhoneNumbers(contactId: Long): JSONArray {
        val numbers = JSONArray()

        try {
            context.contentResolver.query(
                ContactsContract.CommonDataKinds.Phone.CONTENT_URI,
                arrayOf(ContactsContract.CommonDataKinds.Phone.NUMBER),
                "${ContactsContract.CommonDataKinds.Phone.CONTACT_ID} = ?",
                arrayOf(contactId.toString()),
                null,
            )?.use { cursor ->
                val numberIndex = cursor.getColumnIndexOrThrow(
                    ContactsContract.CommonDataKinds.Phone.NUMBER
                )
                while (cursor.moveToNext()) {
                    val number = cursor.getString(numberIndex) ?: continue
                    numbers.put(number)
                }
            }
        } catch (e: Exception) {
            Log.e(TAG, "getPhoneNumbers: failed for contact $contactId", e)
        }

        return numbers
    }

    private fun getEmails(contactId: Long): JSONArray {
        val emails = JSONArray()

        try {
            context.contentResolver.query(
                ContactsContract.CommonDataKinds.Email.CONTENT_URI,
                arrayOf(ContactsContract.CommonDataKinds.Email.DATA),
                "${ContactsContract.CommonDataKinds.Email.CONTACT_ID} = ?",
                arrayOf(contactId.toString()),
                null,
            )?.use { cursor ->
                val emailIndex = cursor.getColumnIndexOrThrow(
                    ContactsContract.CommonDataKinds.Email.DATA
                )
                while (cursor.moveToNext()) {
                    val email = cursor.getString(emailIndex) ?: continue
                    emails.put(email)
                }
            }
        } catch (e: Exception) {
            Log.e(TAG, "getEmails: failed for contact $contactId", e)
        }

        return emails
    }
}
