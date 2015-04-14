#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <security/pam_appl.h>

#include <glib.h>

#define SERVICE_NAME "gala-lockscreen"

int converse (int n, const struct pam_message **msg, struct pam_response **response, void *data)
{
	int i;
	struct pam_response *reply = NULL;
	char buf[PAM_MAX_RESP_SIZE];

	if ((reply = calloc (n, sizeof (*reply))) == NULL)
		return PAM_BUF_ERR;

	for (i = 0; i < n; i++) {
		reply[i].resp_retcode = 0;
		reply[i].resp = NULL;

		switch (msg[i]->msg_style) {
			case PAM_PROMPT_ECHO_OFF:
				reply[i].resp = strdup (data);
				if (reply[i].resp == NULL) goto fail;
				break;
			case PAM_PROMPT_ECHO_ON:
				fputs (msg[i]->msg, stderr);
				if (fgets (buf, sizeof (buf), stdin) == NULL) goto fail;
				reply[i].resp = strdup (buf);
				if (reply[i].resp == NULL) goto fail;
			case PAM_ERROR_MSG:
				fputs (msg[i]->msg, stderr);
				if (strlen (msg[i]->msg) > 0
					&& msg[i]->msg[strlen (msg[i]->msg) - 1] != '\n')
					fputc ('\n', stderr);
				break;
			case PAM_TEXT_INFO:
				fputs (msg[i]->msg, stdout);
				if (strlen (msg[i]->msg) > 0
					&& msg[i]->msg[strlen (msg[i]->msg) - 1] != '\n')
					fputc ('\n', stdout);
				break;
			default:
				goto fail;
		}
	}

	*response = reply;
	return PAM_SUCCESS;

fail:
	for (i = 0; i < n; i++) {
		if (reply[i].resp != NULL) {
			memset (reply[i].resp, 0, strlen (reply[i].resp));
			free (reply[i].resp);
		}
	}
	memset (reply, 0, n * sizeof (*reply));
	*response = NULL;

	return PAM_CONV_ERR;
}

gboolean pam_auth (char* user, char* password)
{
	int status;
	static pam_handle_t *pam_handle;
	struct pam_conv pam_converse = { converse, password };

	status = pam_start (SERVICE_NAME, user, &pam_converse, &pam_handle);
	if (status != PAM_SUCCESS)
		return FALSE;

	status = pam_set_item (pam_handle, PAM_TTY, ":0.0");
	if (status != PAM_SUCCESS)
		return FALSE;

	pam_set_item (pam_handle, PAM_USER_PROMPT, "Username: ");
	if (status != PAM_SUCCESS)
		return FALSE;

	status = pam_authenticate (pam_handle, 0);
	if (status != PAM_SUCCESS)
		return FALSE;

	return TRUE;
}

