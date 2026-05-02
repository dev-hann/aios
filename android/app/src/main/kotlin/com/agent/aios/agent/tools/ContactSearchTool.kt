package com.agent.aios.agent.tools

import android.Manifest
import android.content.pm.PackageManager
import android.provider.ContactsContract
import com.agent.aios.AgentEngine
import com.agent.aios.domain.ToolContext
import org.json.JSONArray
import org.json.JSONObject

class ContactSearchTool : AgentEngine.ExtendedTool {
    override val name = "contact_search"
    override val description = "Search contacts by name/phone. Args: {query, limit}"
    override val parameters = """{"query": "string, name or phone number to search for", "limit": "integer, max results to return (default 10)"}"""

    override fun execute(args: String, toolContext: ToolContext): String {
        return try {
            val context = toolContext.appContext
            if (context.checkSelfPermission(Manifest.permission.READ_CONTACTS) != PackageManager.PERMISSION_GRANTED) {
                return "Error: READ_CONTACTS permission not granted. Grant it in Phone Control settings."
            }

            val json = JSONObject(args)
            val query = json.optString("query", "").trim()
            val limit = json.optInt("limit", 10)

            if (query.isBlank()) return "Error: 'query' parameter required"

            val results = JSONArray()
            val seenNames = mutableSetOf<String>()

            searchContacts(
                selection = "${ContactsContract.CommonDataKinds.Phone.DISPLAY_NAME} LIKE ?",
                selectionArgs = arrayOf("%$query%"),
                limit = limit,
                results = results,
                seenNames = seenNames,
                context = context
            )

            if (results.length() < limit) {
                searchContacts(
                    selection = "${ContactsContract.CommonDataKinds.Phone.NUMBER} LIKE ?",
                    selectionArgs = arrayOf("%$query%"),
                    limit = limit,
                    results = results,
                    seenNames = seenNames,
                    context = context
                )
            }

            if (results.length() == 0) {
                "No contacts found matching '$query'"
            } else {
                results.toString(2)
            }
        } catch (e: Exception) {
            "Error: ${e.message}"
        }
    }

    private fun searchContacts(
        selection: String,
        selectionArgs: Array<String>,
        limit: Int,
        results: JSONArray,
        seenNames: MutableSet<String>,
        context: android.content.Context
    ) {
        context.contentResolver.query(
            ContactsContract.CommonDataKinds.Phone.CONTENT_URI,
            arrayOf(
                ContactsContract.CommonDataKinds.Phone.DISPLAY_NAME,
                ContactsContract.CommonDataKinds.Phone.NUMBER,
                ContactsContract.CommonDataKinds.Phone.CONTACT_ID
            ),
            selection,
            selectionArgs,
            "${ContactsContract.CommonDataKinds.Phone.DISPLAY_NAME} ASC"
        )?.use { cursor ->
            while (cursor.moveToNext() && results.length() < limit) {
                val name = cursor.getString(0) ?: continue
                val phone = cursor.getString(1) ?: continue
                val contactId = cursor.getString(2) ?: continue

                if (seenNames.contains(name.lowercase())) continue
                seenNames.add(name.lowercase())

                val contact = JSONObject()
                contact.put("name", name)
                contact.put("phone", phone)
                contact.put("email", getEmailForContact(contactId, context))
                results.put(contact)
            }
        }
    }

    private fun getEmailForContact(contactId: String, context: android.content.Context): String {
        context.contentResolver.query(
            ContactsContract.CommonDataKinds.Email.CONTENT_URI,
            arrayOf(ContactsContract.CommonDataKinds.Email.ADDRESS),
            "${ContactsContract.CommonDataKinds.Email.CONTACT_ID} = ?",
            arrayOf(contactId),
            null
        )?.use { cursor ->
            if (cursor.moveToFirst()) {
                return cursor.getString(0) ?: ""
            }
        }
        return ""
    }
}
